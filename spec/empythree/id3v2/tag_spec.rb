require File.dirname(__FILE__) + '/../../../lib/empythree'
require File.dirname(__FILE__) + '/../../common_helpers'

include CommonHelpers

describe Empythree::ID3v2::Tag do
  describe "An empty tag" do
    subject { Empythree::ID3v2::Tag.new(StringIO.new("ID3\x03\x00\x00\x00\x00\x00\x00")) }
    its(:version) { should == Empythree::ID3v2::ID3V2_3_0 }
    its(:unsynchronized) { should == false }
    its(:extended_header) { should == false }
    its(:compression) { should == false }
    its(:experimental) { should == false }
    its(:footer) { should == false }
    its(:size) { should == 10 }
    its(:frames) { should == [] }
  end
end
