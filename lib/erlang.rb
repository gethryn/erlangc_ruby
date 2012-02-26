#CONFIGURATION OF DEFAULT VALUES FROM YAML FILE
#adjust yaml location if required
require 'yaml'
default_vals = YAML::parse( File.open ( "config.yaml" ) )
DEFAULT_SVLGOAL = default_vals['svl_goal'].value.to_i || 80
DEFAULT_ASAGOAL = default_vals['asa_goal'].value.to_i || 20
DEFAULT_INTERVAL = default_vals['interval'].value.to_i || 1800
DEFAULT_MAXOCC = default_vals['max_occ'].value.to_i || 100
MAX_AGENTS = default_vals['max_agents'].value.to_i || 2500

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
      if object.is_a?(Array)
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
    
    def validCPI?(object)
        numeric_between?(object,1,9999) 
    end
    
    def validInterval?(interval)
        numeric_in_list?(interval,[900,1800,3600])
    end
    
    def validAHT?(object)
        numeric_between?(object,1,3600)
    end
    
    def validSvlGoal?(object)
        numeric_between?(object,1,100)
    end
    
    def validASAGoal?(object)
        numeric_between?(object,1,3600)
    end
    
    def validMaxOcc?(object)
        numeric_between?(object,1,100)
    end
    
    def validInputs?( cpi_val, aht_val )
      validCPI?(cpi_val) && validAHT?(aht_val)
    end
    
    def check_inputs(cpi,aht,interval,svl_goal,asa_goal,max_occ)
      
      #key inputs: CPI and AHT
      @cpi = cpi # mandatory input, no default
      @aht = aht # mandatory input, no default
      
      #interval
      if validInterval?(interval) 
        @interval = interval 
      else
        @interval = DEFAULT_INTERVAL
        @warning << "#{interval} is an invalid Interval Length, default used [#{DEFAULT_INTERVAL}]"
        p "#{interval} is an invalid Interval Length, default used [#{DEFAULT_INTERVAL}]" 
      end
      
      #service level goal
      if validSvlGoal?(svl_goal)
        @svl_goal = svl_goal 
      else
        @svl_goal = DEFAULT_SVLGOAL
        @warning << "#{svl_goal} is an invalid Service Level Goal default used [#{DEFAULT_SVLGOAL}]"
        p "#{svl_goal} is an invalid Service Level Goal default used [#{DEFAULT_SVLGOAL}]"
      end
      
      #Avg Speed of Answer Goal
      if validASAGoal?(asa_goal) 
        @asa_goal = asa_goal
      else
        @asa_goal = DEFAULT_ASAGOAL
        @warning << "#{asa_goal} is an invalid Avg Speed of Answer Goal, default used [#{DEFAULT_ASAGOAL}]"
        p "#{asa_goal} is an invalid Avg Speed of Answer Goal, default used [#{DEFAULT_ASAGOAL}]"
      end
      
      #Maximum Occupancy Goal
      if validMaxOcc?(max_occ) 
        @max_occ = max_occ
      else
        @max_occ = DEFAULT_MAXOCC
        @warning << "#{max_occ} is an invalid Maximum Occupancy, default used [#{DEFAULT_MAXOCC}]"
        p "#{max_occ} is an invalid Maximum Occupancy, default used [#{DEFAULT_MAXOCC}]"
      end
    end
    
end

class ErlangRequest
  
  include ErlangFunctions
  include ErlangInputTests
    
  # define the list of attributes, and metaprogram reader modules.
  attributes = %w[cpi aht interval svl_goal asa_goal max_occ svl_result occ_result 
                  asa_result detail_result error warning]
  attributes.each do |a|
    attr_reader a
  end
  
  # create an ErlangRequest, if response contains @error something has gone wrong.
  def initialize( cpi, 
                  aht,
                 interval = DEFAULT_INTERVAL, 
                 svl_goal = DEFAULT_SVLGOAL, 
                 asa_goal = DEFAULT_ASAGOAL, 
                 max_occ = DEFAULT_MAXOCC)
    @error = []
    @warning = []
      
    if validInputs?( cpi, aht )
      check_inputs(cpi,aht,interval,svl_goal,asa_goal,max_occ)
      
      @valid = true
      @error << nil
      @agents_required = self.agents_required
      @svl_result = self.svl(@agents_required)
      @asa_result = self.asa(@agents_required)
      @occ_result = self.rho(@agents_required)
      @detail_result = self.optimum_array
      return self
    else
      @valid = false
      @error << "Invalid information supplied, cannot continue - CPI: #{cpi}, AHT: #{aht}."
      @warning << nil
      return nil
    end
  end
  
  def valid?
    @valid
  end

  def invalid?
    ! self.valid?
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
    svl_ok, optimum, i = false, 0, 1
    while svl_ok == false && i <= MAX_AGENTS
      if  self.svl(i) >= (@svl_goal.to_f / 100) && self.rho(i) <= 1.0 &&
          self.rho(i) <= (@max_occ.to_f / 100) && self.asa(i) <= @asa_goal &&
          self.valid?
            svl_ok = true
            optimum = i
      end
      i += 1
    end
    @error << "MAX_AGENTS exceeded" if i == (MAX_AGENTS+1)
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