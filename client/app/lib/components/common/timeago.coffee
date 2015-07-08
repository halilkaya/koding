kd      = require 'kd'
React   = require 'kd-react'
timeago = require 'timeago'

module.exports = class TimeAgo extends React.Component

  @propTypes =
    from : React.PropTypes.string.isRequired

  constructor: (props) ->

    super props

    now = new Date

    @state =
      from        : @props.from or now
      lastUpdated : now


  componentDidMount: ->

    @_interval = kd.utils.repeat 60000, => @setState { lastUpdated: new Date }


  componentWillUnmount: ->

    kd.utils.killRepeat @_interval


  render: -> <time>{timeago @state.from}</time>

