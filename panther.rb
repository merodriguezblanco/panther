require 'octokit'
require 'optparse'
require 'erb'
require 'byebug'

arguments = {}

# Parse options from Command Line
#
OptionParser.new do |opts|
  opts.banner = "Usage: panther.rb [arguments]"

  opts.on('--labels', 'Migrates labels') { |o| arguments[:labels] = true }
  opts.on('--milestones', 'Migrates milestones') { |o| arguments[:milestones] = true }
  opts.on('--issues', 'Migrates issues') { |o| arguments[:issues] = true }
  opts.on('--comments', 'Migrates comments') { |o| arguments[:comments] = true }

  opts.on('--source-token=TOKEN', 'Personal token for the GitHub where you are migrating from') do |o|
    arguments[:source_token] = o
  end
  opts.on('--source-domain=DOMAIN', 'Domain for GitHub where you are migrating from') do |o|
    arguments[:source_domain] = o
  end
  opts.on('--source-organization=ORG', 'Organization in GitHub source where repository lives') do |o|
    arguments[:source_organization] = o
  end
  opts.on('--destination-token=TOKEN', 'Personal token for GitHub destination') do |o|
    arguments[:dest_token] = o
  end
  opts.on('--destination-organization=ORG', 'Organization in GitHub destination where repository will be migrated') do |o|
    arguments[:dest_organization] = o
  end
  opts.on('--repository=REPOSITORY', 'Name of the repository to be migrated') do |o|
    arguments[:repository_name] = o
  end
end.parse!

# Setup environment
#
source_api_endpoint     = "https://#{arguments[:source_domain]}/api/v3/"
source_repository       = "#{arguments[:source_organization]}/#{arguments[:repository_name]}"
destination_repository  = "#{arguments[:dest_organization]}/#{arguments[:repository_name]}"

LABELS_ATTRIBUTES = %i(
  name
).freeze

MILESTONES_ATTRIBUTES = %i(
  title
  state
  description
  due_on
).freeze

ISSUE_ATTRIBUTES = %i(
  number
  state
).freeze

COMMENT_ATTRIBUTES = %i(
  body
).freeze

issue_template = "**Issue by [<%= user_name %>](<%= user_url %>)**
_<%= date %>_
_Originally opened as <%= url %>_

----

<%= body %>"

comment_template = "</a>**Comment by [<%= user_name %>](<%= user_url %>)**
_<%= date %>_

---

<%= body %>"

# Log Octokit requests to file
#
stack = Faraday::RackBuilder.new do |builder|
  builder.response :logger
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

# Configure Octokit
#
Octokit.middleware = stack
Octokit.auto_paginate = true

#Octokit.configure do |config|
  #config.api_endpoint = source_api_endpoint
#end

source = Octokit::Client.new(
  api_endpoint: source_api_endpoint,
  access_token: arguments[:source_token]
)

destination = Octokit::Client.new(
  access_token: arguments[:dest_token]
)

begin
  # Fetch repository labels
  if arguments[:label]
    labels = source.labels(source_repository)

    labels.each_with_object([]) do |label, memo|
      memo << label.select { |k, _| LABELS_ATTRIBUTES.include? k }.to_h
    end
  end

  # Fetch repository milestones
  if arguments[:milestones]
    milestones = source.list_milestones(source_repository)

    milestones.each_with_object([]) do |label, memo|
      memo << milestones.select { |k, _| MILESTONES_ATTRIBUTES.include? k }.to_h
    end
  end

  # Fetch repository issues
  if arguments[:issues]
    issues = source.list_issues(source_repository, state: 'all')

    issues.each do |issue|
      # Check if issue is not a Pull Request
      if issue.pull_request.nil?
        issue_labels = source.labels_for_issue(source_repository, issue.number)
        labels = issue_labels.map { |i| i[:name] }
        issue_options = issue.select { |k, _| ISSUE_ATTRIBUTES.include? k }.to_h
        issue_template_locals = {
          user_name: issue[:user][:login],
          user_url: issue[:user][:url],
          date: issue[:created_at],
          url: issue[:html_url],
          body: issue[:body]
        }
        issue_body = ERB.new(issue_template).result(OpenStruct.new(issue_template_locals).instance_eval { binding })

        # Create issue with state=open
        migrated_issue = destination.create_issue(destination_repository, issue.title, issue_body, issue_options)

        # Update issue state
        if issue.state != 'open'
          destination.update_issue(destination_repository, migrated_issue.number, issue_options)
        end

        # Add labels to issue
        destination.add_labels_to_an_issue(destination_repository, migrated_issue.number, labels)

        # Fetch comments for all issues
        if arguments[:comments]
          comments = source.issue_comments(source_repository, issue.number)

          comments.each do |comment|
            comment_template_locals = {
              user_name: comment[:user][:login],
              user_url: comment[:user][:url],
              date: comment[:created_at],
              body: comment[:body]
            }
            comment_body = ERB.new(comment_template).result(OpenStruct.new(comment_template_locals).instance_eval { binding })
            destination.add_comment(destination_repository, migrated_issue.number, comment_body)
          end
        end
      end
    end
  end
rescue Octokit::Error => e
  puts 'NOOOOOO! Something went wrong!', e
end
