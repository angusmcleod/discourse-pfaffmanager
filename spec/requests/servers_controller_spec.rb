# frozen_string_literal: true
require 'rails_helper'

describe Pfaffmanager::ActionsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:another_user) { Fabricate(:user) }
  fab!(:trust_level_2) { Fabricate(:user, trust_level: TrustLevel[2]) }
  before do
    Jobs.run_immediately!
    stub_request(:get, "https://api.mailgun.net/v3/domains").
    with(
      headers: {
     'Accept'=>'*/*',
     'Host'=>'api.mailgun.net',
     'User-Agent'=>'excon/0.76.0'
      }).
    to_return(status: 200, body: "", headers: {})
    stub_request(:get, "https://api.digitalocean.com/v2/account").
    with(
      headers: {
     'Authorization'=>'Bearer do-boguskey',
     'Host'=>'api.digitalocean.com'
      }).
    to_return(status: 200, body: '{"account": { "status":"active"}}', headers: {})
    stub_request(:get, "https://bogus.discourse.invalid/admin/dashboard.json").
    with(
      headers: {
     'Api-Key'=>'bogus-discourse-key',
     'Api-Username'=>'system',
     'Host'=>'bogus.discourse.invalid'
      }).
    to_return(status: 200, body: '{
      updated_at: "2020-10-26T17:21:00.678Z",
      version_check: {
      installed_version: "2.6.0.beta4",
      installed_sha: "abb00c3780987678fbc6f21ab0c8e46ac297ca75",
      installed_describe: "v2.6.0.beta4 +56",
      git_branch: "tests-passed",
      updated_at: "2020-10-26T17:01:08.197Z",
      latest_version: "2.6.0.beta4",
      critical_updates: false,
      missing_versions_count: 0,
      stale_data: false
      }}', headers: {})

end

  it 'can list' do
    sign_in(user)
    get "/pfaffmanager/servers.json"
    expect(response.status).to eq(200)
  end

  it 'can create from params' do
    sign_in(user)
    puts "create from params user id #{user}"
    s=Pfaffmanager::Server.createServerFromParams(user_id: user.id)
    puts "from params created #{s}, #{s.id} for #{user.id}"
    expect(s.id).not_to be_nil
  end

  it 'can create for  user_id' do
    sign_in(user)
    s=Pfaffmanager::Server.createServerForUser(user.id)
    puts "create for user id created #{s}, #{s.id} for #{user.id}"
    expect(s.id).not_to be_nil
  end

  it 'can create from params with mg api key' do
    sign_in(user)
    s=Pfaffmanager::Server.createServerFromParams(user_id: user.id, mg_api_key: 'mg_boguskey')
    puts "created #{s}, #{s.id} for #{user.id}"
    expect(s.id).not_to be_nil
  end

  it 'can create from params with do api key' do
    sign_in(user)
    s=Pfaffmanager::Server.createServerFromParams(user_id: user.id, do_api_key: 'do-boguskey')
    puts "created #{s}, #{s.id} for #{user.id}"
    expect(s.id).not_to be_nil
  end

  it 'can have a discourse_api_key and update version fields' do
    sign_in(user)
    s=Pfaffmanager::Server.createServerFromParams(user_id: user.id, 
      do_api_key: 'do-boguskey',
      mg_api_key: 'mg_boguskey',
      hostname: 'bogus.discourse.invalid')
    puts "created #{s}, #{s.id} for #{user.id}"
    s.discourse_api_key='bogus-discourse-key'
    s.save
    expect(s.server_status_json).not_to be_nil
    expect(s.installed_version='2.6.0.beta4')
    expect(s.installed_sha='abb00c3780987678fbc6f21ab0c8e46ac297ca75')
    expect(s.git_branch='tests-passed')
  end


end
