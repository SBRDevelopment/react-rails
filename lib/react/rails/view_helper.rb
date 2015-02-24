module React
  module Rails
    module ViewHelper

      # Render a UJS-type HTML tag annotated with data attributes, which
      # are used by react_ujs to actually instantiate the React component
      # on the client.
      def react_component(name, args = {}, options = {}, initial_state = nil, &block)

        if initial_state
          React::Renderer.initial_state(initial_state)
        end

        # Sets prerender = true always because it's critical to the project
        options[:prerender] = true
        if options[:prerender] == true
          args[:prerender] = true
        else
          args[:prerender] = false
        end

        options = {:tag => options} if options.is_a?(Symbol)
        block = Proc.new{concat React::Renderer.render(name, args)} if options[:prerender] == true

        html_options = options.reverse_merge(:data => {})
        html_options[:data].tap do |data|
          data[:react_class] = name
          data[:react_props] = React::Renderer.react_props(args) unless args.empty?
        end

        html_tag = html_options[:tag] || :div
        
        # remove internally used properties so they aren't rendered to DOM
        [:tag, :prerender].each{|prop| html_options.delete(prop)}

        #abort html_tag.inspect
        
        content_tag(html_tag, '', html_options, &block)
      end
    end
  end
end