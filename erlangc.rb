# Currently working to convert the FLOAT types to BIGDECIMAL / other big type to handle higher
# numbers of agents.

# Calculates the factorial of a number (i.e. n!)
def fact(n)
	if n==0
		1
	else
		n * fact(n-1)
	end
end

# Calculates the poisson probability given the number of agents (m) and the traffic intensity (u)
# use cuml = 0 for a standard poisson, and cuml = 1 for a cumulative poisson.
def poisson(m,u,cuml)
  result = 0.0 #.to_d
	if cuml == 0
		result = ((Math::E**-u)*((u**m)/fact(m)))
	else
		for k in (0..(m))
			result += (((Math::E**-u)*(u**k))/fact(k))
		end
	end
	result
end


# Calculates the Erlang-C value given a number of agents (m) and traffic intensity (u)
# The Erlang-C formula calculates the likelihood a call will have to wait to be answered.
def erlangc(m,u)
  rho = u.to_f/m
  occ = 1.0-rho
	result = poisson(m,u,0) / 
					( poisson(m,u,0) + (occ * poisson(m-1,u,1)))
	result
end


# Converts calls_per_interval(cpi), length_of_interval(interval) and avg_handling_time(aht)
# into a traffic intensity figure.  All numbers should be in seconds.  A standard interval is
# usually 30 mins, or 1800 seconds.
def traffic_intensity(cpi,interval,aht)
  result = cpi.to_f / interval * aht
  result
end

# Determines the probability that a call will be answered within the goal speed of answer.
# e.g. an 80/20 svl means that there is an 80% probability calls will be answered within 20 secs.
def svl(cpi,interval,aht,m,asa_goal)
  u = traffic_intensity(cpi,interval,aht)
  result = 1.0-(erlangc(m,u)*Math::E**((-(m-u))*asa_goal.to_f/aht))
  result
end


# Determines the average number of seconds a call will wait to be answered.
def asa(cpi,interval,aht,m)
  u = traffic_intensity(cpi,interval,aht)
  rho = u.to_f/m
  occ = 1.0-rho
  result = (erlangc(m,u)*aht) / (m.to_f * occ)
  result
end


# The inverse of Erlang-C: the probability calls will be immediately answered.
def imm_ans(cpi,interval,aht,m)
  u = traffic_intensity(cpi,interval,aht)
  result = 1.0-erlangc(m,u)
  result
end

# calculates the occupancy of agents at the given svl
# total of m agents, and traffic intensity u
def occupancy(cpi,interval,aht,m)
  u = traffic_intensity(cpi,interval,aht)
  rho = (u.to_f/m)
  rho
end


# determines the optimum number of agents to meet a service level goal.
def how_many_agents (cpi,interval,aht,sl_goal,asa_goal)
  sl_goal = sl_goal.to_f/100
  for i in (1..500)
    sl = svl(cpi,interval,aht,i,asa_goal)
    if sl > sl_goal
      result = i
      break
    end
    if i % 100 == 0
      puts "#{i} agent(s) and counting..."
    end
  end
  result
end


# Increase the agents required (m) by the shrinkage factor applicable to the interval (se)
def schedule_efficiency (m,se)
  result = (m.to_f * (1.0+(se.to_f/100))).ceil
  result
end
  

def optimum_staff(cpi,interval,aht,sl_goal,asa_goal,se)
  optimum_lvl = how_many_agents(cpi,interval,aht,sl_goal,asa_goal)
  low_lvl = optimum_lvl-5
  high_lvl = optimum_lvl+5
  puts "For #{cpi} calls in #{interval} seconds with a SL Goal of #{sl_goal}% in #{asa_goal} secs:"
  puts "Shrinkage of #{se}% is assumed."
  puts "=============================================================================================="
  for i in (low_lvl..high_lvl)
    puts "#{i} agents [#{schedule_efficiency(i,se)} w/shrink]: SVL=#{(svl(cpi,interval,aht,i,asa_goal)*100).to_i}/#{asa_goal}  ASA=#{asa(cpi,interval,aht,i).to_i} secs#{' <<< OPTIMUM' if i == optimum_lvl}"
  end
end