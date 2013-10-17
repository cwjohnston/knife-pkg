#
# Copyright 2013, Holger Amann <holger@fehu.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require 'knife-pkg'

module Knife
  module Pkg
    class AptPackageController < PackageController

      def initialize(node, session, opts = {})
        super(node, session, opts)
      end

      def dry_run_supported?
        true
      end

      def update_pkg_cache
        exec("#{sudo}apt-get update")
      end

      def last_pkg_cache_update
        raise_update_notifier_missing! unless update_notifier_installed?

        result = nil
        begin
          result = exec("stat -c %y /var/lib/apt/periodic/update-success-stamp")
          Time.parse(result.stdout.chomp)
        rescue RuntimeError => e
          e.backtrace.each { |l| Chef::Log.debug(l) }
          Chef::Log.warn(e.message)
          Time.now - (max_pkg_cache_age + 100)
        end
      end

      def installed_version(package)
        exec("dpkg -p #{package.name} | grep -i Version: | awk '{print $2}' | head -1").stdout.chomp
      end

      def update_version(package)
        exec("#{sudo} apt-cache policy #{package.name} | grep Candidate | awk '{print $2}'").stdout.chomp
      end

      def available_updates
        packages = Array.new
        raise_update_notifier_missing! unless update_notifier_installed?
        result = exec("#{sudo}/usr/lib/update-notifier/apt_check.py -p")
        result.stderr.split("\n").each do |item|
          package = Package.new(item)
          package.version = update_version(package)
          packages << package
        end
        packages
      end

      def update_package!(package)
        cmd_string = "#{sudo} DEBIAN_FRONTEND=noninteractive apt-get install #{package.name} -y -o Dpkg::Options::='--force-confold'"
        cmd_string += " -s" if @options[:dry_run]
        exec(cmd_string)
      end

      def update_notifier_installed?
        exec("dpkg-query -W update-notifier-common 2>/dev/null || echo 'false'").stdout.chomp != 'false'
      end

      def raise_update_notifier_missing!
        raise RuntimeError, "No update-notifier(-common) installed!? Install it and try again!"
      end
    end
  end
end
