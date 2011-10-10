#class that dynamically defines properties and defaults them to 0.0 on the fly
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
    
    if instance_variable_get(attr_name).nil?
      instance_variable_set(attr_name, 0.0)
    end
    
    #after we define send the message
    send sym, *args
  end
end