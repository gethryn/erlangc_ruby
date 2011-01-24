module ErlangFunctions
  
  def factorial(n)
      n==0 ? 1 : (n * factorial(n-1))
  end
  
  def poisson(m , u, cuml)
    result = 0.0
    if cuml == false
      result = ((Math.exp(-u.to_f) * u.to_f**m) / factorial(m))
    else
      for k in (0..m)
        result += poisson(k,u,false)
      end
    end
    return result
  end
end

class ErlangRequest
  
  include ErlangFunctions
    
  # define the list of attributes, and metaprogram reader modules.
  attributes = %w[cpi interval aht svl_goal asa_goal occ_goal svl_result occ_result 
                  asa_result detail_result error]
  attributes.each do |a|
    attr_reader a
  end
  
  # create an ErlangRequest, if response contains @error something has gone wrong.
  def initialize( cpi, interval, aht, svl_goal, asa_goal, occ_goal)
    
    # there HAS to be a better way of doing this!
    if ((cpi.is_a?(Fixnum) || cpi.is_a?(Float) || cpi.is_a?(NilClass))) &&
       ((interval.is_a?(Fixnum) || interval.is_a?(Float) || interval.is_a?(NilClass)))&&
       ((aht.is_a?(Fixnum) || aht.is_a?(Float) || aht.is_a?(NilClass))) &&
       ((svl_goal.is_a?(Fixnum) || svl_goal.is_a?(Float) || svl_goal.is_a?(NilClass))) &&
       ((asa_goal.is_a?(Fixnum) || asa_goal.is_a?(Float) || asa_goal.is_a?(NilClass))) &&
       ((occ_goal.is_a?(Fixnum) || occ_goal.is_a?(Float) || occ_goal.is_a?(NilClass)))
       
        @cpi = cpi||0 > 0 ? cpi.to_i : nil 
        @interval = interval||0.between?(1,3600) ? interval.to_i : 1800
        @aht = aht||0.between?(1,3600) ? aht.to_i : nil
        @svl_goal = svl_goal||0.between?(1,100) ? svl_goal.to_f : 80.0
        @asa_goal = asa_goal||0 > 0 ? asa_goal.to_f : 20.0
        @occ_goal = occ_goal||0.between?(1,100) ? occ_goal.to_f : 100.0
        @valid = self.valid?
        @agents_required = self.agents_required
        @svl_result = self.svl(@agents_required)
        @asa_result = self.asa(@agents_required)
        @occ_result = self.rho(@agents_required)
        @detail_result = self.optimum_array
    else
      return @error = "Invalid information supplied to ErlangRequest Initialize method"
    end
  end
  
  def invalid?
    @cpi == 0 || @aht == 0 || @cpi.nil? || @aht.nil?
  end
  
  def valid?
    not self.invalid?
  end

  def traffic_intensity
    self.valid? ? (@cpi.to_f / @interval.to_f * @aht.to_f) : nil
  end
  
  def rho(m)
    m > 0 ? (self.traffic_intensity / m.to_f) : nil
  end  
  
  def erlangc(m)
    return nil if self.invalid?
    result = 0.0
    u = self.traffic_intensity
    rho = self.rho(m)
    result = poisson(m,u,false) / (poisson(m,u,false)+((1-rho)*poisson(m-1,u,true)))
    return result
  end
  
  def svl(m)
    u = self.traffic_intensity
    result = (1.0-(erlangc(m) * Math.exp((-(m-u)) * (@asa_goal / @aht))))
    return self.valid? ? result : nil
  end
  
  def asa(m)
    result = self.valid? ? (self.erlangc(m) * @aht) / (m * (1-self.rho(m))) : nil
  end
  
  def agents_required
    svl_ok, optimum, i = false, 0, 1
    while svl_ok == false
      if  self.svl(i) >= (@svl_goal.to_f / 100) && self.rho(i) <= 1.0 &&
          self.rho(i) <= (@occ_goal.to_f / 100) && self.asa(i) <= @asa_goal &&
          self.valid?
            svl_ok = true
            optimum = i
      end
      i += 1
    end
    return optimum || 0
  end
  
  def optimum_staff(offset)
    result = {}
    i = @agents_required + offset.to_i || 0
    if i > 0
      result = {:agents => i, :occ => self.rho(i) * 100, :svl => self.svl(i) * 100, :asa => self.asa(i), 
                :optimum_offset => offset }
    else
      result = {:agents => nil, :occ => nil, :svl => nil, :asa => nil, :optimum_offset => nil}
    end
    return result
  end
  
  def optimum_array(format=false)
    result = []
    for i in (-5..5)
      result << optimum_staff(i)
    end
    if format == true
      puts "Agents,Occupancy,Service Level,ASA,Optimum Offset"
      result.each do |r|
        printf("%03i,%5.1f%%,%5.1f%%,%7.1f, %+i\n", 
                r[:agents], r[:occ].to_f, r[:svl].to_f, r[:asa].to_f,r[:optimum_offset])
      end
    else
      return result
    end
  end
  
end