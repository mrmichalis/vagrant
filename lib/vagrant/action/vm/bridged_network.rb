require 'log4r'

module Vagrant
  module Action
    module VM
      # This action sets up any bridged networking for the virtual
      # machine.
      class BridgedNetwork
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant::action::vm::bridged_network")

          @app = app
        end

        def call(env)
          @env = env

          networks = bridged_networks
          @logger.debug("Must configure #{networks.length} bridged networks")

          if !networks.empty?
            # Determine what bridged interface to connect to for each
            # network. This returns the same array with the `bridge`
            # key available with the interface.
            networks = determine_bridged_interface(networks)

            # Status output
            env[:ui].info I18n.t("vagrant.actions.vm.bridged_networking.preparing")
            networks.each do |options|
              env[:ui].info I18n.t("vagrant.actions.vm.bridged_networking.bridging",
                                   :adapter => options[:adapter],
                                   :bridge =>  options[:bridge])
            end

            # Setup the network interfaces on the VM if we need to
            setup_network_interfaces(networks)
          end

          @app.call(env)

          if !networks.empty?
            @env[:ui].info I18n.t("vagrant.actions.vm.bridged_networking.enabling")

            # Prepare for new networks
            @env[:vm].guest.prepare_bridged_networks(networks)

            # Enable the networks
            @env[:vm].guest.enable_bridged_networks(networks)
          end
        end

        def bridged_networks
          results = []
          @env[:vm].config.vm.networks.each do |type, args|
            if type == :bridged
              options = args[0] || {}

              results << { :adapter => 2 }.merge(options)
            end
          end

          results
        end

        def determine_bridged_interface(networks)
          bridgedifs = @env[:vm].driver.read_bridged_interfaces

          results = []
          networks.each do |network|
            # TODO: Allow choosing the bridged interface. For now, we just use the
            # first one blindly.
            options = network.dup
            options[:bridge] = bridgedifs[0][:name]
            @logger.info("Bridging #{options[:adapter]} => #{options[:bridge]}")

            results << options
          end

          results
        end

        def setup_network_interfaces(networks)
          adapters = []

          networks.each do |options|
            adapters << {
              :adapter => options[:adapter] + 1,
              :type    => :bridged,
              :bridge  => options[:bridge]
            }
          end

          # Enable the adapters
          @logger.info("Enabling bridged networking adapters")
          @env[:vm].driver.enable_adapters(adapters)
        end
      end
    end
  end
end