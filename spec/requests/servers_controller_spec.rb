# frozen_string_literal: true
require 'rails_helper'

describe Pfaffmanager::ServersController do
  fab!(:user) { Fabricate(:user) }
  fab!(:create_user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:another_user) { Fabricate(:user) }
  fab!(:trust_level_2) { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:discourse_server) { Fabricate(:server,
    user_id: user.id,
    hostname: 'working.discourse.invalid',
    discourse_api_key: 'working-discourse-key')}
  SiteSetting.pfaffmanager_upgrade_playbook = 'spec-test.yml'
  SiteSetting.pfaffmanager_do_install = 'true'

  create_server_group_name = "create_server"
  group = Group.create(name: create_server_group_name)
  looking = Group.find_by_name(group.name)
  SiteSetting.pfaffmanager_create_server_group = create_server_group_name
  unlimited_server_group_name = "unlimited_servers"
  unlimited_group = Group.create(name: unlimited_server_group_name)
  SiteSetting.pfaffmanager_unlimited_server_group = unlimited_server_group_name

  server_manager_group_name = "UpgradeServers"
  server_manager_group = Group.create(name: server_manager_group_name)
  SiteSetting.pfaffmanager_server_manager_group = server_manager_group_name

  before do
    Jobs.run_immediately!
    stub_request(:get, "https://working.discourse.invalid/admin/dashboard.json").
      with(
        headers: {
          'Api-Key' => 'working-discourse-key',
          'Api-Username' => 'system',
          'Host' => 'working.discourse.invalid'
        }).
      to_return(status: 200, body: '{
      "updated_at": "2020-10-26T17:21:00.678Z",
      "version_check": {
      "installed_version": "2.6.0.beta4",
      "installed_sha": "abb00c3780987678fbc6f21ab0c8e46ac297ca75",
      "installed_describe": "v2.6.0.beta4 +56",
      "git_branch": "tests-passed",
      "updated_at": "2020-10-26T17:01:08.197Z",
      "latest_version": "2.6.0.beta4",
      "critical_updates": false,
      "missing_versions_count": 0,
      "stale_data": false
      }}', headers: {})
  end

  after do
    # TODO: figure out how to do these with a fabricator?
    SiteSetting.pfaffmanager_create_server_group = ""
    SiteSetting.pfaffmanager_unlimited_server_group = ""
    SiteSetting.pfaffmanager_server_manager_group = ""
    Group.find_by_name(create_server_group_name).destroy
    Group.find_by_name(unlimited_server_group_name).destroy
    Group.find_by_name(server_manager_group_name).destroy
  end

it 'can list if no servers' do
  sign_in(user)
  get "/pfaffmanager/servers.json"
  expect(response.status).to eq(200)
end

it 'can list when there is a server' do
  sign_in(user)
  hostname = 'bogus.invalid'
  #TODO: should fabricate this
  s = Pfaffmanager::Server.createServerFromParams(user_id: user.id,
                                                  hostname: hostname , request_status: 'not updated')
  get "/pfaffmanager/servers.json"
  expect(response.status).to eq(200)
  json = response.parsed_body
  expect(json['servers'][0]['hostname']).to eq(hostname)
  expect(json['servers'].count).to eq(1)
end

it 'cannot list if not logged in' do
  get "/pfaffmanager/servers.json"
  expect(response.status).to eq(403)
end

it 'CreateServer group can create a server and be removed from group' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_create_server_group)
  group.add(user)
  sign_in(user)
  params = {}
  params['server'] = { user_id: user.id }
  post '/pfaffmanager/servers.json', params: params
  expect(response.status).to eq(200)
  server = response.parsed_body['server']
  expect(server["id"]).not_to eq nil
  new_server = Pfaffmanager::Server.find(server['id'])
  expect(new_server).not_to eq nil
  expect(group.users.where(id: user.id)).to be_empty
end

it 'UnlimitedCreate group can create a server and NOT be removed from group' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_unlimited_server_group)
  group.add(user)
  sign_in(user)
  params = {}
  params['server'] = { user_id: user.id }
  post '/pfaffmanager/servers.json', params: params
  expect(response.status).to eq(200)
  server = response.parsed_body['server']
  expect(server["id"]).not_to eq nil
  new_server = Pfaffmanager::Server.find(server['id'])
  expect(new_server).not_to eq nil
  expect(group.users.where(id: user.id)).not_to be_empty
end

it 'Admin can create a server' do
  sign_in(admin)
  params = {}
  params['server'] = { user_id: admin.id }
  post '/pfaffmanager/servers.json', params: params
  expect(response.status).to eq(200)
  server = response.parsed_body['server']
  expect(server["id"]).not_to eq nil
  new_server = Pfaffmanager::Server.find(server['id'])
  expect(new_server).not_to eq nil
end

it 'CreateServer fails if not in create group' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_create_server_group)
  sign_in(user)
  params = {}
  params['server'] = { user_id: user.id }
  post '/pfaffmanager/servers.json', params: params
  expect(response.status).to eq(200)
  server = response.parsed_body['server']
  expect(server["id"]).to eq nil
end

it 'can update status' do
  request_status = 'new status'
  sign_in(admin)
  s = Pfaffmanager::Server.createServerFromParams(user_id: user.id,
                                                  hostname: 'bogus.invalid' , request_status: 'not updated')
  puts "can update status created server id: #{s.id}"
  params = { server: { git_branch: 'not' } }

  expect {
    put "/pfaffmanager/servers/#{s.id}", params: params
  }.not_to change { s.request_status }
  expect(response.status).to eq(200)
end

it 'server manager group can initiate upgrades' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_server_manager_group)
    group.add(user)
    sign_in(user)
    params = {}
    params['server'] = { id: discourse_server.id, user_id: user.id, request: 1 }
    put "/pfaffmanager/servers/#{discourse_server.id}.json", params: params
    expect(response.status).to eq(200)
    expect(response.parsed_body['success']).to eq "OK"
    discourse_server.reload
    expect(discourse_server.request).to eq -1
    expect(discourse_server.last_action).to eq 'Process rebuild'
end

it 'server manager cannot start upgrade if one is running' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_server_manager_group)
    group.add(user)
    sign_in(user)
    params = {}
    params['server'] = { id: discourse_server.id, user_id: user.id, request: 1 }
    put "/pfaffmanager/servers/#{discourse_server.id}.json", params: params
    expect(response.status).to eq(200)
    expect(response.parsed_body['success']).to eq "OK"
    discourse_server.reload
    expect(discourse_server.request).to eq -1
    expect(discourse_server.last_action).to eq 'Process rebuild'
    rebuild_status = 'spec testing'
    discourse_server.last_action = rebuild_status
    put "/pfaffmanager/servers/#{discourse_server.id}.json", params: params
    expect(discourse_server.last_action).to eq rebuild_status
end

it 'non server managers cannot initiate upgrades' do
  sign_in(user)
    params = {}
    params['server'] = { id: discourse_server.id, user_id: user.id, request: 1 }
    put "/pfaffmanager/servers/#{discourse_server.id}.json", params: params
    expect(response.status).to eq(200)
    expect(response.parsed_body['success']).to eq "OK"
    discourse_server.reload
    expect(discourse_server.request).to be nil
    expect(discourse_server.last_action).to be nil
end

it 'can update smtp parameters' do
  group = Group.find_by_name(SiteSetting.pfaffmanager_server_manager_group)
  sign_in(user)
  smtp_user = 'theuser'
  smtp_password = "smtp-pw"
  smtp_host = 'smtphost.com'
  smtp_port = '1234'
  smtp_notification_email = 'nobody@nowhere.com'
  params = { server: { smtp_host: smtp_host,
                       smtp_password: smtp_password,
                       smtp_port: smtp_port,
                       smtp_user: smtp_user,
                       smtp_notification_email: smtp_notification_email
                      }
            }
put "/pfaffmanager/servers/#{discourse_server.id}.json", params: params
  discourse_server.reload
  expect(response.status).to eq(200)
  expect(response.parsed_body['success']).to eq "OK"
  expect(discourse_server.smtp_host).to eq(smtp_host)
  expect(discourse_server.smtp_password).to eq(smtp_password)
  expect(discourse_server.smtp_user).to eq(smtp_user)
  expect(discourse_server.smtp_port).to eq(smtp_port.to_i)
  expect(discourse_server.smtp_notification_email).to eq(smtp_notification_email)
end

  # it 'does not initiate a new request if one is running'
  #   expect(true).to eq false
  # end
  # it 'does initiate a new request is not running'
  #   expect(true).to eq false
  # end

  # it 'allows a single field to be updated via API'
  # end
  # it 'does not allow a single field to be updated via API if not admin'
  # end

  # it 'can update status' do
  #   request_status = 'new status'
  #   s=Pfaffmanager::Server.createServerFromParams(user_id: user.id,
  #                                                 hostname: 'bogus.invalid' , request_status: 'not updated')
  #   puts "can update status created server id: #{s.id}"
  #   params = {server: {git_branch: 'not'}}

  #   expect {
  #     puts "/pfaffmanager/servers/#{s.id}", params: params
  #   }.not_to change { s.request_status }
  #   #expect(s.git_branch).to eq('new status')
  #   expect(response.status).to eq(200)
  #   #assigns(:request_status).should eq(request_status)
  # end

end
