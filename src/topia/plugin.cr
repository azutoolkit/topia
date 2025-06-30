module Topia
  # Abstract plugin interface - only defines the contract
  abstract class Plugin
    abstract def run(input, args = [] of String)
    abstract def on(event : String)
  end

  # Plugin utilities - dependency injection for messaging
  module PluginUtils
    def self.announce(message, spinner = SPINNER)
      spinner.message = message
    end

    def self.error(message, spinner = SPINNER)
      spinner.error message
    end

    def self.success(message, spinner = SPINNER)
      spinner.success message
    end
  end

  # Base plugin class with utilities - concrete implementations can extend this
  abstract class BasePlugin < Plugin
    def announce(message)
      PluginUtils.announce(message)
    end

    def error(message)
      PluginUtils.error(message)
    end

    def success(message)
      PluginUtils.success(message)
    end

    # Default no-op implementation for lifecycle events
    def on(event : String)
      # Override in subclasses if needed
    end
  end

  # Plugin lifecycle manager
  class PluginLifecycle
    def self.run_plugin(plugin : Plugin, input, args)
      plugin.on("pre_run")
      result = plugin.run(input, args)
      plugin.on("after_run")
      result
    rescue ex
      plugin.on("error")
      raise ex
    end

    def self.run_plugin(plugin : Plugin, input, args, &block : -> Nil)
      plugin.on("pre_run")
      result = plugin.run(input, args)
      block.call
      plugin.on("after_run")
      result
    rescue ex
      plugin.on("error")
      raise ex
    end
  end
end
