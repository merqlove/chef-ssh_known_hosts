#
# Author:: Seth Vargo (<sethvargo@gmail.com>)
# Provider:: entry
#
# Copyright 2013, Seth Vargo
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
#

action :create do
  key = (new_resource.key || `ssh-keyscan -H -p #{new_resource.port} #{new_resource.host} 2>&1`)
  comment = key.split("\n").first || ""
  ssh_user = new_resource.owner || 'root'
  file_path = new_resource.file || node['ssh_known_hosts']['file']

  Chef::Application.fatal! "Could not resolve #{new_resource.host}" if key =~ /getaddrinfo/
  
  # Ensure that the file exists and has minimal content (required by Chef::Util::FileEdit)
  file file_path do
    action        :create
    backup        false
    owner         ssh_user
    group         ssh_user
    content       '# This file must contain at least one line. This is that line.'
    only_if do
      !::File.exists?(file_path) || ::File.new(file_path).readlines.length == 0
    end
  end

  # Use a Ruby block to edit the file
  ruby_block "add #{new_resource.host} to #{file_path}" do
    block do
      file = ::Chef::Util::FileEdit.new(file_path)
      file.insert_line_if_no_match(/#{Regexp.escape(comment)}|#{Regexp.escape(key)}/, key)
      file.write_file
    end
  end
  new_resource.updated_by_last_action(true)
end
