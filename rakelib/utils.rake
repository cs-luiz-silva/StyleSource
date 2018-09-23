# Used constants:
# - MIN_XCODE_VERSION

require 'json'
require 'pathname'

# Utility functions to run Xcode commands, extract versionning info and logs messages
#
class Utils
  COLUMN_WIDTH = 30

  ## [ Run commands ] #########################################################

  # formatter types
  # :xcpretty  : through xcpretty and store in artifacts
  # :raw       : store in artifacts
  # :to_string : run using backticks and return output

  # run a command using xcrun and xcpretty if applicable
  def self.run(command, task, subtask = '', xcrun: false, formatter: :raw)
    commands = if xcrun
                 [*command].map { |cmd| "#{version_select} xcrun #{cmd}" }
               else
                 [*command]
               end
    case formatter
    when :xcpretty then xcpretty(commands, task, subtask)
    when :raw then plain(commands, task, subtask)
    when :to_string then `#{commands.join(' && ')}`
    else raise "Unknown formatter '#{formatter}'"
    end
  end

  ## [ Convenience Helpers ] ##################################################

  def self.podspec_version(file = '*')
    JSON.parse(`bundle exec pod ipc spec #{file}.podspec`)['version']
  end

  def self.podfile_lock_version(pod)
    require 'yaml'
    root_pods = YAML.load_file('Podfile.lock')['PODS'].map { |n| n.is_a?(Hash) ? n.keys.first : n }
    pod_vers = root_pods.select { |n| n.start_with?(pod) }.first # "SwiftGen (x.y.z)"
    /\((.*)\)$/.match(pod_vers)[1] # Just the 'x.y.z' part
  end

  def self.octokit_client
    token   = File.exist?('.apitoken') && File.read('.apitoken')
    token ||= File.exist?('../.apitoken') && File.read('../.apitoken')
    Utils.print_error('No .apitoken file found') unless token
    require 'octokit'
    Octokit::Client.new(access_token: token)
  end

  def self.top_changelog_version(changelog_file = 'CHANGELOG.md')
    `grep -m 1 '^## ' "#{changelog_file}" | sed 's/## //'`.strip
  end

  def self.top_changelog_entry(changelog_file = 'CHANGELOG.md')
    tag = top_changelog_version
    `sed -n /'^## #{tag}$'/,/'^## '/p "#{changelog_file}"`.gsub(/^## .*$/, '').strip
  end

  ## [ Print info/errors ] ####################################################

  # print an info header
  def self.print_header(str)
    puts "== #{str.chomp} ==".format(:yellow, :bold)
  end

  # print an info message
  def self.print_info(str)
    puts str.chomp.format(:green)
  end

  # print an error message
  def self.print_error(str)
    puts str.chomp.format(:red)
  end

  # format an info message in a 2 column table
  def self.table_info(label, msg)
    puts "#{label.ljust(COLUMN_WIDTH)} 👉  #{msg}"
  end

  # format a result message in a 2 column table
  def self.table_result(result, label, error_msg)
    if result
      puts "#{label.ljust(COLUMN_WIDTH)} ✅"
    else
      puts "#{label.ljust(COLUMN_WIDTH)} ❌  - #{error_msg}"
    end
    result
  end

  ## [ Private helper functions ] ##################################################

  # run a command, pipe output through 'xcpretty' and store the output in CI artifacts
  def self.xcpretty(cmd, task, subtask)
    name = (task.name + (subtask.empty? ? '' : "_#{subtask}")).gsub(/[:-]/, '_')
    command = [*cmd].join(' && ')

    if ENV['CIRCLECI']
      Rake.sh "set -o pipefail && (#{command}) | tee \"#{ENV['CIRCLE_ARTIFACTS']}/#{name}_raw.log\" | " \
        "bundle exec xcpretty --color --report junit --output \"#{ENV['CIRCLE_TEST_REPORTS']}/xcode/#{name}.xml\""
    elsif system('which xcpretty > /dev/null')
      Rake.sh "set -o pipefail && (#{command}) | bundle exec xcpretty -c"
    else
      Rake.sh command
    end
  end
  private_class_method :xcpretty

  # run a command and store the output in CI artifacts
  def self.plain(cmd, task, subtask)
    name = (task.name + (subtask.empty? ? '' : "_#{subtask}")).gsub(/[:-]/, '_')
    command = [*cmd].join(' && ')

    if ENV['CIRCLECI']
      Rake.sh "set -o pipefail && (#{command}) | tee \"#{ENV['CIRCLE_ARTIFACTS']}/#{name}_raw.log\""
    else
      Rake.sh command
    end
  end
  private_class_method :plain

  # select the xcode version we want/support
  def self.version_select
    @version_select ||= compute_developer_dir(MIN_XCODE_VERSION)
  end
  private_class_method :version_select

  # Return the "DEVELOPER_DIR=..." prefix to use in order to point to the best Xcode version
  #
  # @param [String|Float|Gem::Requirement] version_req
  #        The Xcode version requirement.
  #        - If it's a Float, it's converted to a "~> x.y" requirement
  #        - If it's a String, it's converted to a Gem::Requirement as is
  # @note If you pass a String, be sure to use "~> " in the string unless you really want
  #       to point to an exact, very specific version
  #
  def self.compute_developer_dir(version_req)
    version_req = Gem::Requirement.new("~> #{version_req}") if version_req.is_a?(Float)
    version_req = Gem::Requirement.new(version_req) unless version_req.is_a?(Gem::Requirement)
    # if current Xcode already fulfills min version don't force DEVELOPER_DIR=...
    current_xcode_version = `xcodebuild -version`.split("\n").first.match(/[0-9.]+/).to_s
    return '' if version_req.satisfied_by? Gem::Version.new(current_xcode_version)

    supported_versions = all_xcode_versions.select { |app| version_req.satisfied_by?(app[:vers]) }
    latest_supported_xcode = supported_versions.sort_by { |app| app[:vers] }.last

    # Check if it's at least the right version
    if latest_supported_xcode.nil?
      raise "\n[!!!] StyleSource requires Xcode #{version_req}, but we were not able to find it. " \
        "If it's already installed, either `xcode-select -s` to it, or update your Spotlight index " \
        "with 'mdimport /Applications/Xcode*'\n\n"
    end

    %(DEVELOPER_DIR="#{latest_supported_xcode[:path]}/Contents/Developer")
  end
  private_class_method :compute_developer_dir

  # @return [Array<Hash>] A list of { :vers => ... , :path => ... } hashes
  #                       of all Xcodes found on the machine using Spotlight
  def self.all_xcode_versions
    xcodes = `mdfind "kMDItemCFBundleIdentifier = 'com.apple.dt.Xcode'"`.chomp.split("\n")
    xcodes.map do |path|
      { vers: Gem::Version.new(`mdls -name kMDItemVersion -raw "#{path}"`), path: path }
    end
  end
  private_class_method :all_xcode_versions
end

# Colorization support for Strings
#
class String
  # colorization
  FORMATTING = {
    # text styling
    bold: 1,
    faint: 2,
    italic: 3,
    underline: 4,
    # foreground colors
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    # background colors
    bg_black: 40,
    bg_red: 41,
    bg_green: 42,
    bg_yellow: 43,
    bg_blue: 44,
    bg_magenta: 45,
    bg_cyan: 46,
    bg_white: 47
  }.freeze

  # only enable formatting if terminal supports it
  if `tput colors`.chomp.to_i >= 8
    def format(*styles)
      styles.reduce('') { |r, s| r << "\e[#{FORMATTING[s]}m" } << "#{self}\e[0m"
    end
  else
    def format(*_styles)
      self
    end
  end
end
