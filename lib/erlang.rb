require 'yaml'

default_vals = YAML::parse ( <<EOY )
svl_goal: 80
asa_goal: 20
interval: 1800
max_occ: 100
EOY

DEFAULT_SVL = default_vals.value['svl_goal']
DEFAULT_ASA = default_vals.value['asa_goal']
DEFAULT_INTERVAL = default_vals.value['interval']
DEAFULT_MAXOCC = default_vals.value['max_occ']

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

module ErlangInputTests
    
    def numeric?(object)
      if object.is_a(Array)
        false_count = 0
        object.each do |val| 
          return false unless numeric?(val)
        end
      else
        true if Float(object) rescue false
      end
    end

    def numeric_between?( object, start, finish )
      numeric?(object) && object.between?( start , finish )
    end

    def numeric_in_list?( object, list )
      numeric?(object) && list.include?(object)
    end
    
    def validCPI?(cpi)
        numeric_between?(cpi,1,9999) 
    end
    
    def validInterval?(interval)
        numeric_in_list?(interval,[900,1800,3600])
    end
    
    def validAHT?(aht)
        numeric_between?(aht,1,3600)
    end
    
    def validSvlGoal?(svl_goal)
        numeric_between?(svl_goal,1,100)
    end
    
    def validASAGoal?(asa_goal)
        numeric_between?(asa_goal,1,3600)
    end
    
    def validMaxOcc?(max_occ)
        numeric_between?(max_occ,1,100)
    end
    
    def validInputs?( cpi, aht )
      validCPI?(cpi) && validAHT?(aht)
    end
    
    def check_inputs(cpi,interval,aht,svl_goal,asa_goal,occ_goal)
      @cpi = cpi # mandatory input, no default
      @aht = aht # mandatory input, no default
      @interval = validInterval?(interval) ? interval : DEFAULT_INTERVAL
      @svl_goal = validSvlGoal?(svl_goal) ? svl_goal : DEFAULT_SVLGOAL
      @asa_goal = validASAGoal?(asa_goal) ? asa_goal : DEFAULT_ASAGOAL
      @max_occ = validMaxOcc?(max_occ) ? max_occ : DEFAULT_MAXOCC
    end
    
end

class ErlangRequest
  
  include ErlangFunctions
  include ErlangInputTests
    
  # define the list of attributes, and metaprogram reader modules.
  attributes = %w[cpi interval aht svl_goal asa_goal occ_goal svl_result occ_result 
                  asa_result detail_result error]
  attributes.each do |a|
    attr_reader a
  end
  
  # create an ErlangRequest, if response contains @error something has gone wrong.
  def initialize( cpi, interval, aht, svl_goal, asa_goal, occ_goal )
    
    if validInputs?( cpi, aht )
      check_inputs(cpi,interval,aht,svl_goal,asa_goal,occ_goal)
      @valid = true
      @agents_required = self.agents_required
      @svl_result = self.svl(@agents_required)
      @asa_result = self.asa(@agents_required)
      @occ_result = self.rho(@agents_required)
      @detail_result = self.optimum_array
      return self
    else
      @valid = false
      @error = "Invalid information supplied to ErlangRequest Initialize method"
      return nil
    end
  end
  
  def valid?
    @valid
  end
  
  def traffic_intensity
    self.valid? ? (@cpi.to_f / @interval.to_f * @aht.to_f) : nil
  end
  
  def rho(m)
    self.valid? && m > 0 ? (self.traffic_intensity / m.to_f) : nil
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
    return nil if self.invalid?
    u = self.traffic_intensity
    result = (1.0-(erlangc(m) * Math.exp((-(m-u)) * (@asa_goal / @aht))))
    return result
  end
  
  def asa(m)
    result = self.valid? ? (self.erlangc(m) * @aht) / (m * (1-self.rho(m))) : nil
  end
  
  def imm_ans(m)
    result = self.valid? ? 1.0 - erlangc(m) : nil
  end
  
  def agents_required
    return nil if self.invalid?
    svl_ok, optimum, i = false, 0, self.traffic_intensity.to_i
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
    return nil if self.invalid?
    result = {}
    i = @agents_required + offset.to_i || 0
    if i > 0
      result = {:agents => i, :occ => self.rho(i) * 100, :svl => self.svl(i) * 100, :asa => self.asa(i), 
                :imm_ans => self.imm_ans(i) * 100, :optimum_offset => offset }
    else
      result = {:agents => nil, :occ => nil, :svl => nil, :asa => nil, :imm_ans => nil, :optimum_offset => nil}
    end
    return result
  end
  
  def optimum_array(format=false)
    return nil if self.invalid?
    result = []
    for i in (-5..5)
      result << optimum_staff(i)
    end
    if format == true
      puts "Agents,Occupancy,Service Level,ASA,Immediate Answer,Optimum Offset"
      result.each do |r|
        printf("%03i,%5.1f%%,%5.1f%%,%7.1f, %5.1f%%,%+i\n", 
                r[:agents], r[:occ].to_f, r[:svl].to_f, r[:asa].to_f, r[:imm_ans].to_f, r[:optimum_offset])
      end
    else
      return result
    end
  end
  
end