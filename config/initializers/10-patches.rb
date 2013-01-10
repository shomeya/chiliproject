#-- encoding: UTF-8
#-- copyright
# ChiliProject is a project management system.
#
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

# Patches active_support/core_ext/load_error.rb to support 1.9.3 LoadError message
if RUBY_VERSION >= '1.9.3'
  MissingSourceFile::REGEXPS << [/^cannot load such file -- (.+)$/i, 1]
end

require 'active_record'

module ActiveRecord
  class Base
    include Redmine::I18n

    # Translate attribute names for validation errors display
    def self.human_attribute_name(attr)
      l("field_#{attr.to_s.gsub(/_id$/, '')}")
    end
  end
end

module ActiveRecord
  class Errors
    def full_messages(options = {})
      full_messages = []

      @errors.each_key do |attr|
        @errors[attr].each do |message|
          next unless message

          if attr == "base"
            full_messages << message
          elsif attr == "custom_values"
            # Replace the generic "custom values is invalid"
            # with the errors on custom values
            @base.custom_values.each do |value|
              value.errors.each do |attr, msg|
                full_messages << value.custom_field.name + ' ' + msg
              end
            end
          else
            attr_name = @base.class.human_attribute_name(attr)
            full_messages << attr_name + ' ' + message.to_s
          end
        end
      end
      full_messages
    end
  end
end

module ActionView
  module Helpers
    module DateHelper
      # distance_of_time_in_words breaks when difference is greater than 30 years
      def distance_of_date_in_words(from_date, to_date = 0, options = {})
        from_date = from_date.to_date if from_date.respond_to?(:to_date)
        to_date = to_date.to_date if to_date.respond_to?(:to_date)
        distance_in_days = (to_date - from_date).abs

        I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
          case distance_in_days
            when 0..60     then locale.t :x_days,             :count => distance_in_days.round
            when 61..720   then locale.t :about_x_months,     :count => (distance_in_days / 30).round
            else                locale.t :over_x_years,       :count => (distance_in_days / 365).floor
          end
        end
      end
    end

    module FormHelper
      # Returns an input tag of the "date" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   date_field(:user, :birthday, :size => 20)
      #   # => <input type="date" id="user_birthday" name="user[birthday]" size="20" value="#{@user.birthday}" />
      #
      #   date_field(:user, :birthday, :class => "create_input")
      #   # => <input type="date" id="user_birthday" name="user[birthday]" value="#{@user.birthday}" class="create_input" />
      #
      # NOTE: This will be part of rails 4.0, the monkey patch can be removed by then.
      def date_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("date", options)
      end
    end

    # As ActionPacks metaprogramming will already have happened when we're here,
    # we have to tell the FormBuilder about the above date_field ourselvse
    #
    # NOTE: This can be remove when the above ActionView::Helpers::FormHelper#date_field is removed
    class FormBuilder
      self.field_helpers << "date_field"

      def date_field(method, options = {})
        @template.date_field(@object_name, method, objectify_options(options))
      end
    end

    module FormTagHelper
      # Creates a date form input field.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   date_field_tag 'meeting_date'
      #   # => <input id="meeting_date" name="meeting_date" type="date" />
      #
      # NOTE: This will be part of rails 4.0, the monkey patch can be removed by then.
      def date_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.stringify_keys.update("type" => "date"))
      end
    end
  end
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| "#{html_tag}" }

# Adds :async_smtp and :async_sendmail delivery methods
# to perform email deliveries asynchronously
module AsynchronousMailer
  %w(smtp sendmail).each do |type|
    define_method("perform_delivery_async_#{type}") do |mail|
      Thread.start do
        send "perform_delivery_#{type}", mail
      end
    end
  end
end

ActionMailer::Base.send :include, AsynchronousMailer

# TMail::Unquoter.convert_to_with_fallback_on_iso_8859_1 introduced in TMail 1.2.7
# triggers a test failure in test_add_issue_with_japanese_keywords(MailHandlerTest)
module TMail
  class Unquoter
    class << self
      alias_method :convert_to, :convert_to_without_fallback_on_iso_8859_1
    end
  end
end

module ActionController
  module MimeResponds
    class Responder
      def api(&block)
        any(:xml, :json, &block)
      end
    end
  end

  # Backported fix for
  # CVE-2012-2660
  # https://groups.google.com/group/rubyonrails-security/browse_thread/thread/f1203e3376acec0f
  #
  # CVE-2012-2694
  # https://groups.google.com/group/rubyonrails-security/browse_thread/thread/8c82d9df8b401c5e
  #
  # TODO: Remove this once we are on Rails >= 3.2.6
  require 'action_controller/request'
  class Request
    protected

    # Remove nils from the params hash
    def deep_munge(hash)
      keys = hash.keys.find_all { |k| hash[k] == [nil] }
      keys.each { |k| hash[k] = nil }

      hash.each_value do |v|
        case v
        when Array
          v.grep(Hash) { |x| deep_munge(x) }
          v.compact!
        when Hash
          deep_munge(v)
        end
      end

      hash
    end

    def parse_query(qs)
      deep_munge(super)
    end
  end
end

# Backported fix for CVE-2012-3465
# https://groups.google.com/d/msg/rubyonrails-security/FgVEtBajcTY/tYLS1JJTu38J
# TODO: Remove this once we are on Rails >= 3.2.8
require 'action_view/helpers/sanitize_helper'
module ActionView::Helpers::SanitizeHelper
  def strip_tags(html)
    self.class.full_sanitizer.sanitize(html)
  end
end

# Backported fix for CVE-2012-3464
# https://groups.google.com/d/msg/rubyonrails-security/kKGNeMrnmiY/r2yM7xy-G48J
# TODO: Remove this once we are on Rails >= 3.2.8
require 'active_support/core_ext/string/output_safety'
class ERB
  module Util
    HTML_ESCAPE["'"] = '&#39;'

    if RUBY_VERSION >= '1.9'
      # A utility method for escaping HTML tag characters.
      # This method is also aliased as <tt>h</tt>.
      #
      # In your ERB templates, use this method to escape any unsafe content. For example:
      # <%=h @person.name %>
      #
      # ==== Example:
      # puts html_escape("is a > 0 & a < 10?")
      # # => is a &gt; 0 &amp; a &lt; 10?
      def html_escape(s)
        s = s.to_s
        if s.html_safe?
          s
        else
          s.gsub(/[&"'><]/, HTML_ESCAPE).html_safe
        end
      end
    else
      def html_escape(s) #:nodoc:
        s = s.to_s
        if s.html_safe?
          s
        else
          s.gsub(/[&"'><]/n) { |special| HTML_ESCAPE[special] }.html_safe
        end
      end
    end

    # Aliasing twice issues a warning "discarding old...". Remove first to avoid it.
    remove_method(:h)
    alias h html_escape

    module_function :h

    singleton_class.send(:remove_method, :html_escape)
    module_function :html_escape
  end
end
require 'action_view/helpers/tag_helper'
module ActionView::Helpers::TagHelper
  def escape_once(html)
    ActiveSupport::Multibyte.clean(html.to_s).gsub(/[\"\'><]|&(?!([a-zA-Z]+|(#\d+));)/) { |special| ERB::Util::HTML_ESCAPE[special] }
  end
end
