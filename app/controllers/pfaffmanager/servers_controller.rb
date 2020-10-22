# frozen_string_literal: true
require 'byebug'

module Pfaffmanager
  class ServersController < ::ApplicationController
    requires_plugin Pfaffmanager

    before_action :ensure_logged_in

    def index
      puts "\n\n\n\nServer controller user #{current_user.username} in the house.\n\n\n\n"
      servers = ::Pfaffmanager::Server.where(user_id: current_user.id)
      puts "-----------------> Server controller found #{servers.count} servers"
      render_json_dump({ servers: servers })
    end

    def show
      # TODO: Allow admin to see server of other users
      server = ::Pfaffmanager::Server.find_by(user_id: current_user.id, id: params[:id])
      render_json_dump({ server: server })
    end

    def create
      puts "Creating in Controller!!!!!! user_id: #{params[:server][:user_id]}"
      server = ::Pfaffmanager::Server.createServer(params[:server][:user_id])
      server = ::Pfaffmanager::Server.find_by(user_id: current_user.id)
      render_json_dump({ server: server})
    end

    def set_server_status
      puts "Set server status in the contro9ller!!!"
    end

    def update
      puts "\n\n#{params}\n\n\n\nserver UPDATE controller id: #{params[:id]}\nrequest_status: #{params[:request_status]}\n\n\n\n\n\n"
      request = params[:server][:request].to_i
      puts "------------------> GOT REQUEST: #{request}"
      if server = ::Pfaffmanager::Server.find_by(id: params[:id])
        data = server_params
        puts "Data: #{data}"
        if !data[:request_status].nil?
          server.request_status = data[:request_status]
          server.request_status_updated_at = Time.now
          puts "\n\REQUEST STATUS UPDATE with #{data[:request_status]} at #{server.request_status_updated_at}\n\n"
        elsif !request.nil?
          puts "Request exists: #{request}"
          if request >= 0
            server.request = request
          else
            puts "\n\nprocess running skip rebuild!!\n\n"
          end
          if request > 0
            server.request_status = "Processing"
          end
        else
          puts "\n\nserver controller update!"
          server.user_id = data[:user_id] if data[:user_id]
          server.hostname = data[:hostname] if data[:hostname] 
          server.discourse_api_key = data[:discourse_api_key] if data[:discourse_api_key]
          server.do_api_key = data[:do_api_key] if data[:do_api_key]
          server.mg_api_key = data[:mg_api_key] if data[:mg_api_key]
          server.maxmind_license_key = data[:maxmind_license_key]
          # don't try to start a build if one is running
        end

        puts "server controller update about to save R: #{server.request}"
        server.save

        if server.errors.present?
          return render_json_error(server.errors.full_messages)
        else
          return render json: success_json
        end
      end

      render json: failed_json
    end
  

    def server_params
      params.require(:server).permit(
        :user_id,
        :hostname,
        :do_api_key,
        :mg_api_key,
        :maxmind_license_key,
        :discourse_api_key,
        :request,
        :request_status
      )
    end
  end
end
