# frozen_string_literal: true

require 'active_support'

%w(
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
).each do |railtie|
  require railtie
end

require 'caffeinate/perform'
require 'caffeinate/mail_ext'
require 'caffeinate/engine'
require 'caffeinate/drip'
require 'caffeinate/periodical_drip'
require 'caffeinate/action'
require 'caffeinate/url_helpers'
require 'caffeinate/configuration'
require 'caffeinate/dripper/base'
require 'caffeinate/deliver_async'
require 'caffeinate/dripper_collection'

module Caffeinate
  extend Perform

  def self.dripper_collection
    @dripper_collection ||= DripperCollection.new
  end

  # Global configuration
  def self.config
    @config ||= Configuration.new
  end

  # Yields the configuration
  def self.setup
    yield config
  end
end
