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
        var jsdom = require('jsdom');
        var global = global || this;
        var self = self || this;

        var html = '<html><head></head><body></body></html>';

        jsdom.env(html, function(err, window) {
          var console = global.console || {};
          var document = window.document;
          var navigator = window.navigator;
          ['error', 'log', 'info', 'warn'].forEach(function (fn) {
            if (!(fn in console)) {
              console[fn] = function () {};
            }
          });

          #{@@react_js.call};
          var React = global.React;
          #{@@components_js.call};
        });
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
      @context ||= ExecJS.compile_async(self.class.combined_js)
      #@context ||= ExecJS.compile(self.class.combined_js)
    end

    def render(component, args={})
      react_props = React::Renderer.react_props(args)
      jscode = <<-JS
        function() {
          return React.renderToString(React.createElement(#{component}, #{react_props}));
        }()
      JS
      context.eval(jscode).html_safe      
    rescue ExecJS::ProgramError => e
      raise PrerenderError.new(component, react_props, e)
    end
  end
end
