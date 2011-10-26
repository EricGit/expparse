require 'CSV'

#A class that defines property (set/get) on the fly as required
#Defaults properties to 0.0 so we can sum without presetting
class DynAttrClass
  def method_missing(sym, *args, &block)
    name_of_method = sym.to_s
    attr_name = ""
    (class << self; self; end).class_eval do
      if (name_of_method[-1] == "=") then
        #define setter and instance variable
        attr_name = "@#{name_of_method[0..-2]}"
        define_method sym do |*args|
          instance_variable_set(attr_name, args[0])
        end
      else
        #define getter
        attr_name = "@" + name_of_method
        define_method sym do
          instance_variable_get(attr_name)
        end
      end
    end
    
    #default nil values 0.0 for situations like a.b += 12.0
    if instance_variable_get(attr_name).nil?
      instance_variable_set(attr_name, 0.0)
    end
    
    #after we define send the message
    send sym, *args
  end
end

#We're going to read a file and eval on it within the context of this class
#So define helper functions that the eval engine used to define...if, min, max etc.
class Evaluator
  def initialize klasses
    @klass_hash = {}
    klasses.each do |klass|
      instance_eval("@klass_hash['#{klass.downcase}'] = #{klass}.new")
    end
  end
  
  #if we find missing method we assume it's a class, look it up in the hash so we can assign
  def method_missing(sym, *args, &block)
    return @klass_hash[sym.to_s]
  end
  
  #*************** helper functions defined by evaluation engine *************** 
  def roundcent(amount)
    return ((amount * 100).round)/100
  end

  def if_d(a, b, c)
    return b if a
    return c
  end

  def min(a, b)
    if a < b
      return a
    end
    return b
  end

  def max(a, b)
    if a > b
      return a
    end
    return b
  end

  def strequals(a, b)
    return a == b
  end
  
  def lookupband val, arr
    arr.each do |lookup|
      return lookup[1] if lookup[0] == "infinity"
      return lookup[1] if val <=  lookup[0]
    end
  end
  #*************** end helper functions *************** 

  #calculate a single expression file with a single row of data from csv file
  def calc_once calc_file, in_header, in_data, output_variables    
    in_header.each_with_index do | theval, ix |
      eval "#{theval} = #{in_data[ix]}"
    end
    
    file = File.new(calc_file, "r")
    count = 0;
    while (line = file.gets)
      count+=1
      begin
        eval(line)
      rescue Exception => e  
        puts "#{calc_file}(#{count}): " + e.message
      end
    end
    file.close
    
    #output to stdout
    s = ""
    output_variables.each do |output_var|
      s << (eval output_var).to_s
      s << ","
    end    
    puts s
  end
end 

#read a csv file into rows
def read_csv_data file
  rows = []
  readerIn = CSV.open(file, 'r')
  row = readerIn.shift
  while row!= nil && !row.empty?
    rows << row
    row = readerIn.shift
  end
  readerIn.close
  
  return rows
end

#define classes by eval'ing them
def define_classes klasses
  klasses.each do |klassname|
    klass = klassname.gsub(/\b('?[a-z])/) { $1.capitalize } #make uppercase
    #could check to see if not already define but at the minute not important
    #if (eval "defined? #{klass}") != "constant"
      eval "class #{klass} < DynAttrClass \n end"
    #end
  end
end

#format: 
#  ruby expressionparse.rb "Input Output" "output.max output.min output.sum"
klasses = ARGV[0].split
outputs = ARGV[1].split
in_header , *in_rows  = *(read_csv_data 'inputs.csv')  #first, *rest = *many
define_classes klasses

#each row run a test
in_rows.each_with_index do |in_row, ix|
    e = Evaluator.new klasses
    e.calc_once 'expressions.txt', in_header, in_row, outputs
end
