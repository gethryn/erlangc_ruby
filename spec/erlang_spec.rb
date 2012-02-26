require 'erlang'

describe ErlangRequest do
  it "returns a valid ErlangRequest object" do
    e=ErlangRequest.new(342,430,1800,80,20,100)
    e.valid?.should == true
  end
  
  it "returns an invalid object when AHT or CPI is nil or 0" do
    no_cpi=ErlangRequest.new(nil,430,1800,80,20,100)
    no_aht=ErlangRequest.new(342,nil,1800,80,20,100)
    neither=ErlangRequest.new(nil,nil,1800,80,20,100)
    no_cpi.invalid?.should == true
    no_aht.invalid?.should == true
    neither.invalid?.should == true
  end
  
  it "returns a valid number of agents given 342,1800,430,80,20,100 as inputs" do
    e=ErlangRequest.new(342,430,1800,80,20,100)
    e.agents_required.should == 90
  end
  
  it "returns valid output when defaults used" do
    e=ErlangRequest.new(342,430,nil,nil,nil,nil)
    e.svl_goal.should == 80
    e.asa_goal.should == 20
    e.occ_goal.should == 100
    e.interval.should == 1800
    e.valid?.should == true
  end
  
  it "automatically substitutes defaults for non critical inputs" do
    e=ErlangRequest.new(342,430)
    e.svl_goal.should == 80
    e.asa_goal.should == 20
    e.occ_goal.should == 100
    e.interval.should == 1800
    e.valid?.should == true
    e.agents_required.should == 90
    e.warning.count.should == 4
  end
    
    
  it "properly handles blanks or strings passed in error" do
    e=ErlangRequest.new("","430",nil,nil,nil,nil)
    e.error.should == "Invalid information supplied to ErlangRequest Initialize method"
    e.invalid?.should == true
  end
  
end
  