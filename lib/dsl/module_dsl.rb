# DSL for writing linael's module.
# It's backward compatible with the old way of writing modules

# Main function for defining a module.
# Everything should be instide its block.
# Params:
# +name+::         a symbol to name the module
# +config_hash+:: optional hash for configuration. the differents options available are:
# * +:author+:: A string for the name of the module maker. "Zaratan" by default
# * +:require_auth+:: A boolean for saying if an auth method is required or not
# * +:required_mod+:: A list of module names required for this module
# * +:auth+:: A boolean telling if it's an auth module or not
#
# +block+:: definition of the module. Everything here will be executed in the scope of the module.
#
#   linael :test, author: "Skizzk", require_auth: true, required_mod: ["admin"] do
#   end
#   #=> produce a module named Test with Skizzk for author, which require at least an auth method and the module admin.
class Object
  def linael(name, config_hash = {}, &block)
    # Create the class
    new_class = Class.new(Linael::ModuleIRC) do
      generate_all_config(name, config_hash)
      const_set("Options", generate_all_options)
    end # Class.new(Linael::ModuleIRC)

    # Link the module to the right part of linael
    Linael::Modules.const_set(name.to_s.camelize, new_class)

    # Execute the block
    "Linael::Modules::#{name.to_s.camelize}".constantize.class_eval &block if block_given?
  end
end
# This is a trick to use t inside help
class Class
  include R18n::Helpers
end
R18n.set (if LinaelLanguages.is_a? Array
            LinaelLanguages + ['en']
          else
            [LinaelLanguages, 'en']
            end)

# Everything goes there
module Linael
  # Fake interruption for before check
  class InterruptLinael < RuntimeError
  end

  # Modification of ModuleIRC class to describe the DSL methods
  class ModuleIRC
    # Method to describe a feature of the module inside a linael bloc (see Object)
    # Params:
    # +type+:: type of message watched by the method should be in:
    # * +:msg+:: any message
    # * +:cmd+:: any command message (begining with a !)
    # * +:cmdAuth+:: any command which you should be auth on the bot to use
    # * +:join+   :: any join
    # * +:part+   :: any part
    # * +:kick+   :: any kick
    # * +:auth+   :: any auth asking (for :cmdAuth)
    # * +:mode+   :: any mode change
    # * +:nick+   :: any nick change
    # * +:notice+ :: any notice
    #
    # +name+:: the name of the feature
    # +regex+:: the regex that the method should match
    # +config_hash+:: an optional configuration hash (for now, there is no configuration option)
    # +block+:: where we describe what the method should do
    def self.on(type, name, regex = //, _config_hash = {}, &block)
      # Generate regex catching in Options class
      self::Options.class_eval do
        generate_to_catch(name => regex)
      end

      generate_define_method_on(type, name, regex, &block) if block_given?

      # Define the method which will be really called
      # Add the feature to module start
      # TODO add doc here (why unless)
      const_set("ToStart", {}) unless defined?(self::ToStart)
      self::ToStart[type] ||= []
      self::ToStart[type] = self::ToStart[type] << name
    end

    def execute_method(type, msg, options, &block)
      if type == :auth
        instance_exec(msg, options, &block)
      else
        # execute block
        Thread.new do
          begin
            instance_exec(msg, options, &block)
          rescue InterruptLinael
          rescue Exception => e
            puts e.to_s.red
            puts e.backtrace.join("\n").red
          end
        end
      end
    end

    # TODO add it to protected
    def self.generate_define_method_on(type, name, _regex, &block)
      p type, name, _regex, block
      send("define_method", name) do |msg|
        # Is it matching the regex?
        if self.class::Options.send("#{name}?", msg.message)
          # if it's a message: generate options
          options = self.class::Options.new msg.element if msg.element.is_a? Linael::Irc::Privmsg
          execute_method(type, msg, options, &block)
        end
      end
    end

    # Wrapper to add values regex
    # Params:
    # +key+:: is the name of the method (options.name)
    # +value+:: is the regex used to find the result
    def self.value(hash)
      self::Options.class_eval do
        generate_value hash
      end
    end

    # Wrapper to add values regex with a default value
    # Params:
    # +key+:: is the name of the method (options.name)
    # +value+:: is a hash with 2 keys:
    # * +:regexp+:: the matching regex
    # * +:default+:: the default value
    def self.value_with_default(hash)
      self::Options.class_eval do
        generate_value_with_default hash
      end
    end

    # Wrapper to add matching regex to options
    # Params:
    # +key+:: is the name of the method (options.name?)
    # +value+:: is the regex to match
    def self.match(hash)
      self::Options.class_eval do
        generate_match hash
      end
    end

    # Instruction used at the start of the module
    def self.on_init(&block)
      const_set("At_launch", block)
    end

    # Instructions used at load (from save module)
    def self.on_load(&block)
      const_set("At_load", block)
    end

    # An array of strings for help
    def self.help(help_array)
      const_set("Help", help_array)
    end

    def self.db_list(*lists)
      lists.each do |list|
        class_name = name
        define_method(list) do
          Redis::List.new("#{class_name}:#{list}", marshal: true)
        end
      end
    end

    def self.db_value(*values)
      values.each do |value|
        class_name = name
        define_method(value) do
          Redis::Value.new("#{class_name}:#{value}", marshal: true)
        end
      end
    end

    def self.db_hash(*hashes)
      hashes.each do |hash|
        class_name = name
        define_method(hash) do
          Redis::HashKey.new("#{class_name}:#{hash}", marshal: true)
        end
      end
    end

    # Override of normal method
    def load_mod
      instance_eval(&self.class::At_load) if defined?(self.class::At_load)
    end

    # Overide of normal method
    def start!
      add_module(self.class::ToStart)
    end

    def launch
      @master.act_types.each { |t| add_module_irc_behavior t }
    end

    # Overide of normal method
    def initialize(master)
      @master = master
      instance_eval(&self.class::At_launch) if defined?(self.class::At_launch)
      launch
    end

    # A method used to describe preliminary tests in a method
    def before(msg)
      raise(InterruptLinael, "not matching") unless yield(msg)
    end

    # Execute something later
    # Params:
    # +time+:: The time of the execution
    # +hash+:: Params sended to the block
    def at(time, hash = nil, &block)
      Thread.new do
        sleep(time - Time.now)
        instance_exec(hash, &block)
      end
    end

  end
end
