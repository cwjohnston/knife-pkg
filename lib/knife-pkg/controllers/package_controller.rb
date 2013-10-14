require 'knife-pkg'
require 'chef/knife'

module Knife
  module Pkg
    class PackageController

      attr_accessor :node
      attr_accessor :session
      attr_accessor :options
      attr_accessor :ui

      def initialize(node, session, opts = {})
        @node = node
        @session = session
        @options = opts
      end

      def self.ui
        @ui ||= Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
      end

      def sudo
        @options[:sudo] ? 'sudo ' : ''
      end

      # update the package cache 
      # e.g apt-get update
      def update_pkg_cache
        raise NotImplementedError
      end

      # returns the time of the last package cache update
      def last_pkg_cache_update
        raise NotImplementedError
      end

      # returns the version of the installed package
      def installed_version(package)
        raise NotImplementedError
      end

      # returns an array of all available updates
      def available_updates
        raise NotImplementedError
      end

      # updates a package
      # should only execute a 'dry-run' if @options[:dry_run] is set
      # returns a ShellCommandResult
      def update_package!(package)
        raise NotImplementedError
      end

      def self.update!(node, session, packages, opts)
        ctrl = self.init_controller(node, session, opts)
        packages.each do |pkg|
          result = ctrl.update_package!(package)
          if @options[:dry_run] || @options[:verbose]
            ui.info(result.stdout)
            ui.error(result.stderr)
          end
        end
      end

      def self.available_updates(node, session, opts = {})
        ctrl = self.init_controller(node, session, opts)

        if Time.now - ctrl.last_pkg_cache_update > 86400 # 24 hours
          ui.info("Updating package cache...")
          ctrl.update_pkg_cache
        end

        updates = ctrl.available_updates
        updates.each do |update|
          ui.info(ui.color("\t" + update.to_s, :yellow))
        end
      end

      def self.init_controller(node, session, opts)
        begin
          ctrl_name = self.controller_name(node.platform)
          require File.join(File.dirname(__FILE__), ctrl_name)
        rescue LoadError
          raise NotImplementedError, "I'm sorry, but #{node.platform} is not supported!"
        end
        Object.const_get('Knife').const_get('Pkg').const_get("#{ctrl_name.capitalize}PackageController").new(node, session, opts)
      end

      def self.controller_name(platform)
        case platform
        when 'debian', 'ubuntu'
          'debian'
        else
          platform
        end
      end
    end
  end
end
