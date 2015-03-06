require 'connection_pool'

module React  
  class Renderer
    class PrerenderError < RuntimeError
      def initialize(component_name, props, js_message)
        message = "Encountered error \"#{js_message}\" when prerendering #{component_name} with #{props}"
        super(message)
      end
    end

    cattr_accessor :pool

    def self.setup!(react_js, components_js, args={})
      args.assert_valid_keys(:size, :timeout)
      @@react_js = react_js
      @@components_js = components_js
      @@pool.shutdown{} if @@pool
      reset_combined_js!
      @@pool = ConnectionPool.new(:size => args[:size]||10, :timeout => args[:timeout]||20) { self.new }
    end

    def self.render(component, args={})
      @@pool.with do |renderer|
        renderer.render(component, args)
      end
    end

    def self.setup_combined_js
      <<-CODE
        var global = global || this;
        var self = self || this;
        var window = window || this;
        var navigator = navigator || this;

        var console = global.console || {};
        ['error', 'log', 'info', 'warn'].forEach(function (fn) {
          if (!(fn in console)) {
            console[fn] = function () {};
          }
        });

        #{@@react_js.call};
        React = global.React;
        #{@@components_js.call};
      CODE
    end

    def self.reset_combined_js!
      @@combined_js = setup_combined_js
    end

    def self.combined_js
      @@combined_js
    end

    def self.react_props(args={})
      if args.is_a? String
        args
      else
        args.to_json
      end
    end

    def context
      
      final_combined_js = <<-CODE
        var initial_state = {};

        #{self.class.combined_js}
      CODE

      @context ||= ExecJS.compile(final_combined_js)
    end

    cattr_accessor :state

    def self.initial_state(state)
      @@state = state
    end

    def render(component, args={})
      if @@state
        initial_state = React::Renderer.react_props(@@state)
      end

      # sends prerender flag as prop to the react component to
      react_props = React::Renderer.react_props(args)

      func = "renderToString"
      if args.is_a?(Hash) and args[:prerender] == true
        func = "renderToStaticMarkup"
      end

      js_initial_state = ""
      if initial_state
        js_initial_state = "initial_state = #{initial_state};"
      end

      jscode = <<-JS
        function() {
          #{js_initial_state}
          return React.#{func}(React.createElement(#{component}, #{react_props}));
        }()
      JS

      context.eval(jscode).html_safe

    rescue ExecJS::ProgramError => e
      raise PrerenderError.new(component, react_props, e)
    end
  end
end
