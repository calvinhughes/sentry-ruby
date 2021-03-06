require "sentry/breadcrumb_buffer"

module Sentry
  class Scope
    ATTRIBUTES = [:transaction_names, :contexts, :extra, :tags, :user, :level, :breadcrumbs, :fingerprint, :event_processors, :rack_env]

    attr_reader(*ATTRIBUTES)

    def initialize
      set_default_value
    end

    def clear
      set_default_value
    end

    def apply_to_event(event)
      event.tags = tags.merge(event.tags)
      event.user = user.merge(event.user)
      event.extra = extra.merge(event.extra)
      event.contexts = contexts.merge(event.contexts)
      event.fingerprint = fingerprint
      event.level ||= level
      event.transaction = transaction_names.last
      event.breadcrumbs = breadcrumbs
      event.rack_env = rack_env

      unless @event_processors.empty?
        @event_processors.each do |processor_block|
          event = processor_block.call(event)
        end
      end

      event
    end

    def add_breadcrumb(breadcrumb)
      breadcrumbs.record(breadcrumb)
    end

    def clear_breadcrumbs
      @breadcrumbs = BreadcrumbBuffer.new
    end

    def dup
      copy = super
      copy.breadcrumbs = breadcrumbs.dup
      copy.contexts = contexts.deep_dup
      copy.extra = extra.deep_dup
      copy.tags = tags.deep_dup
      copy.user = user.deep_dup
      copy.transaction_names = transaction_names.deep_dup
      copy.fingerprint = fingerprint.deep_dup
      copy
    end

    def set_rack_env(env)
      env = env || {}
      @rack_env = env
    end

    def set_user(user_hash)
      check_argument_type!(user_hash, Hash)
      @user = user_hash
    end

    def set_extras(extras_hash)
      check_argument_type!(extras_hash, Hash)
      @extra = extras_hash
    end

    def set_extra(key, value)
      @extra.merge!(key => value)
    end

    def set_tags(tags_hash)
      check_argument_type!(tags_hash, Hash)
      @tags = tags_hash
    end

    def set_tag(key, value)
      @tags.merge!(key => value)
    end

    def set_contexts(contexts_hash)
      check_argument_type!(contexts_hash, Hash)
      @contexts = contexts_hash
    end

    def set_context(key, value)
      @contexts.merge!(key => value)
    end

    def set_level(level)
      @level = level
    end

    def set_transaction_name(transaction_name)
      @transaction_names << transaction_name
    end

    def transaction_name
      @transaction_names.last
    end

    def set_fingerprint(fingerprint)
      check_argument_type!(fingerprint, Array)

      @fingerprint = fingerprint
    end

    def add_event_processor(&block)
      @event_processors << block
    end

    protected

    # for duplicating scopes internally
    attr_writer(*ATTRIBUTES)

    private

    def check_argument_type!(argument, expected_type)
      unless argument.is_a?(expected_type)
        raise ArgumentError, "expect the argument to be a #{expected_type}, got #{argument.class} (#{argument})"
      end
    end

    def set_default_value
      @breadcrumbs = BreadcrumbBuffer.new
      @contexts = { :os => self.class.os_context, :runtime => self.class.runtime_context }
      @extra = {}
      @tags = {}
      @user = {}
      @level = :error
      @fingerprint = []
      @transaction_names = []
      @event_processors = []
      @rack_env = {}
    end

    class << self
      def os_context
        @os_context ||=
          begin
            uname = Etc.uname
            {
              name: uname[:sysname] || RbConfig::CONFIG["host_os"],
              version: uname[:version],
              build: uname[:release],
              kernel_version: uname[:version]
            }
          end
      end

      def runtime_context
        @runtime_context ||= {
          name: RbConfig::CONFIG["ruby_install_name"],
          version: RUBY_DESCRIPTION || Sentry.sys_command("ruby -v")
        }
      end
    end

  end
end
