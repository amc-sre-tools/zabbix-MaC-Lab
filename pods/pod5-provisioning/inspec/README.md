# InSpec Profiles for Compliance Testing
# Place your InSpec profiles in this directory

# Example example-inspec/profile/inspec.yml:
# name: example-profile
# title: Example InSpec Profile
# maintainer: Test Author
# copyright: Test Author
# copyright_email: test@example.com
# license: Apache-2.0
# summary: An InSpec compliance profile example
# version: 1.0.0
#
# controls:
#   - title: Ensure MySQL is running
#     description: MySQL service should be running
#     tags:
#       - database
#     controls:
#       - mysql_running
#     code: |
#       describe service('mysql') do
#         it { should be_running }
#       end