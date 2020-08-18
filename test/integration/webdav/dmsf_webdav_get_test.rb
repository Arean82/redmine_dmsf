# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2012    Daniel Munn <dan.munn@munnster.co.uk>
# Copyright © 2011-20 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../test_helper', __FILE__)

class DmsfWebdavGetTest < RedmineDmsf::Test::IntegrationTest

  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles,
           :enabled_modules, :dmsf_folders, :dmsf_files, :dmsf_file_revisions

  def test_should_deny_anonymous
    get '/dmsf/webdav'
    assert_response :unauthorized
  end

  def test_should_deny_failed_authentication
    get '/dmsf/webdav', params: nil, headers: credentials('admin', 'badpassword')
    assert_response :unauthorized
  end

  def test_should_permit_authenticated_user
    get '/dmsf/webdav', params: nil, headers: @admin
    assert_response :success
  end

  def test_should_list_dmsf_enabled_project
    get '/dmsf/webdav', params: nil, headers: @admin
    assert_response :success
    assert !response.body.match(@project1.identifier).nil?,
           "Expected to find project #{@project1.identifier} in return data"
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    project1_uri = RedmineDmsf::Webdav::ProjectResource.create_project_name(@project1)
    get '/dmsf/webdav', params: nil, headers: @admin
    assert_response :success
    assert_no_match @project1.identifier, response.body
    assert_match project1_uri, response.body
  end

  def test_should_list_non_dmsf_enabled_project
    @project2.disable_module! :dmsf
    get '/dmsf/webdav', params: nil, headers: @jsmith
    assert_response :success
    assert response.body.match(@project2.identifier)
  end

  def test_should_return_status_404_when_project_does_not_exist
    get '/dmsf/webdav/project_does_not_exist', params: nil, headers: @jsmith
    assert_response :not_found
  end

  def test_should_return_status_404_when_dmsf_not_enabled_for_file
    get "/dmsf/webdav/#{@project2.identifier}/#{@file2.name}", params: nil, headers: @jsmith
    assert_response :not_found
  end

  def test_should_return_status_404_when_dmsf_not_enabled_for_folder
    get "/dmsf/webdav/#{@project2.identifier}/#{@folder3.title}", params: nil, headers: @jsmith
    assert_response :not_found
  end

  def test_should_return_status_200_when_dmsf_not_enabled_for_project
    @project2.disable_module! :dmsf
    get "/dmsf/webdav/#{@project2.identifier}", params: nil, headers: @jsmith
    assert_response :success
    # Folders and files are not listed
    assert response.body.match(@file2.name).nil?
    assert response.body.match(@folder3.title).nil?
  end

  def test_should_not_list_files_without_permissions
    @role.remove_permission! :view_dmsf_files
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @jsmith
    assert_response :success
    # Files are not listed
    assert response.body.match(@file1.name).nil?
    assert response.body.match(@folder1.title)
  end

  def test_should_not_list_folders_without_permissions
    @role.remove_permission! :view_dmsf_folders
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @jsmith
    assert_response :success
    # Folders are not listed
    assert response.body.match(@file1.name)
    assert response.body.match(@folder1.title).nil?
  end

  def test_download_file_from_dmsf_enabled_project
    get "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @admin
    assert_response :success
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    project1_uri = Addressable::URI.escape(RedmineDmsf::Webdav::ProjectResource.create_project_name(@project1))
    get "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @admin
    assert_response :not_found
    get "/dmsf/webdav/#{project1_uri}/test.txt", params: nil, headers: @admin
    assert_response :success
  end

  def test_should_list_dmsf_contents_within_project
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @admin
    assert_response :success
    folder = DmsfFolder.find_by(id: 1)
    assert_not_nil folder
    assert response.body.match(@folder1.title),
           "Expected to find #{folder.title} in return data"
    file = DmsfFile.find_by(id: 1)
    assert_not_nil file
    assert response.body.match(file.name),
           "Expected to find #{file.name} in return data"
  end

  def test_user_assigned_to_project_dmsf_module_not_enabled
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @jsmith
    assert_response :success
  end

  def test_user_assigned_to_archived_project
    @project1.archive
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @jsmith
    assert_response :not_found
  end

  def test_user_assigned_to_project_folder_ok
    get "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: @jsmith
    assert_response :success
  end

  def test_user_assigned_to_project_file_forbidden
    @role.remove_permission! :view_dmsf_files
    get "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @jsmith
    assert_response :forbidden
  end

  def test_user_assigned_to_project_file_ok
    get "/dmsf/webdav/#{@project1.identifier}/test.txt", params: nil, headers: @jsmith
    assert_response :success
  end

  def test_get_file_in_subproject
    get "/dmsf/webdav/#{@project1.identifier}/#{@project3.identifier}/#{@file12.name}", params: nil, headers: @admin
    assert_response :success
  end

  def test_get_folder_in_subproject
    get "/dmsf/webdav/#{@project1.identifier}/#{@project3.identifier}/#{@folder10.title}", params: nil, headers: @admin
    assert_response :success
  end

end
