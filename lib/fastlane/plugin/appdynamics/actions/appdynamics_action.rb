module Fastlane
  module Actions
    class AppdynamicsAction < Action
      def self.connection(host, api_account_name, api_license_key)
        require 'faraday'
        require 'faraday_middleware'

        base_url = "#{host}/eumaggregator/crash-reports/iOSDSym"
        foptions = {
          url: base_url
        }
        Faraday.new(foptions) do |builder|
          builder.request :basic_auth, api_account_name, api_license_key
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def self.run(params)
        Actions.verify_gem!('faraday')
        Actions.verify_gem!('faraday_middleware')

        # Params - API
        host = params[:api_host]
        api_account_name = params[:api_account_name]
        api_license_key = params[:api_license_key]

        has_account_name = !api_account_name.to_s.empty?
        has_license_key = !api_license_key.to_s.empty?

        if !has_account_name || !has_license_key
          UI.user_error!("No account name or license key found for AppDynamics, pass using `api_account_name: 'name'` and `api_license_key: 'key'`")
        end

        # Params - dSYM
        dsym_path = params[:dsym_path]
        dsym_zip_path = Actions.lane_context[SharedValues::DSYM_ZIP_PATH.to_sym]
        dsym_paths = params[:dsym_paths] || []
        dsym_paths += [dsym_path] unless dsym_path.nil?
        dsym_paths += [dsym_zip_path] unless dsym_zip_path.nil?

        # Verify dsym(s)
        dsym_paths = dsym_paths.map { |path| File.absolute_path(path) }
        dsym_paths.each do |path|
          UI.user_error!("dSYM does not exist at path: #{path}") unless File.exist? path
        end

        # Upload dsym(s)
        dsym_paths.compact.map do |dsym|
          upload_dsym(dsym, host, api_account_name, api_license_key)
        end

        UI.success 'dSYMs successfully uploaded to AppDynamics!'
      end

      def self.upload_dsym(dsym, host, api_account_name, api_license_key)
        UI.message "Uploading #{dsym}"
        connection = self.connection(host, api_account_name, api_license_key)

        response = connection.put do |request|
          content_type = 'application/octet-stream'
          request.headers[:content_type] = content_type
          request.headers[:content_length] = File.size(dsym).to_s
          request.body = Faraday::UploadIO.new(dsym, content_type)
        end

        UI.user_error! "Failed uploading dSYM to AppDynamics" unless response.success?
      rescue Exception => exception
        UI.user_error! "Error while trying to upload dSYM to AppDynamics: #{exception}"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload dSYM symbolication files to AppDynamics"
      end

      def self.details
        [
          "This action allows you to upload symbolication files to AppDynamics.",
          "It's extra useful if you use it to download the latest dSYM files from Apple when you",
          "use Bitcode."
        ].join(" ")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_host,
                                       env_name: "APPDYNAMICS_HOST",
                                       description: "API host url for AppDynamics",
                                       default_value: "https://api.eum-appdynamics.com",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :api_account_name,
                                       env_name: "APPDYNAMICS_ACCOUNT_NAME",
                                       description: "Account name for AppDynamics",
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No account name for AppDynamics given, pass using `api_account_name: 'name'`") if value.to_s.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :api_license_key,
                                       env_name: "APPDYNAMICS_LICENSE_KEY",
                                       description: "License key for AppDynamics",
                                       sensitive: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No license key for AppDynamics given, pass using `api_license_key: 'key'`") if value.to_s.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :dsym_path,
                                       env_name: "APPDYNAMICS_DSYM_PATH",
                                       description: "Path to your symbols file. For iOS and Mac provide path to app.dSYM.zip",
                                       default_value: Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH.to_sym],
                                       optional: true,
                                       verify_block: proc do |value|
                                         # validation is done in the action
                                       end),
          FastlaneCore::ConfigItem.new(key: :dsym_paths,
                                       env_name: "APPDYNAMICS_DSYM_PATHS",
                                       description: "Path to an array of your symbols file. For iOS and Mac provide path to app.dSYM.zip",
                                       default_value: Actions.lane_context[SharedValues::DSYM_PATHS.to_sym],
                                       is_string: false,
                                       optional: true,
                                       verify_block: proc do |value|
                                         # validation is done in the action
                                       end)
        ]
      end

      def self.output
        nil
      end

      def self.return_value
        nil
      end

      def self.authors
        ["wedkarz"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.example_code
        [
          'appdynamics(
            api_account_name: "...",
            api_license_key: "...",
            dsym_path: "./App.dSYM.zip"
          )'
        ]
      end
    end
  end
end
