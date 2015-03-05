Foo = React.createClass
  render: ->
    R.div null, 'Foobar'

# Because Coffee files are in an anonymous function,
# expose it for server rendering tests
window.Foo = Foo
