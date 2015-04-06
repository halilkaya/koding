$ = require 'jquery'
remote = require('app/remote').getInstance()
whoami = require 'app/util/whoami'
getNick = require 'app/util/nick'

###*
 * It makes a request to the backend and gets session id
 * and creates a session with that session id.
 *
 * TODO: add proper error handling
 *
 * @param {SocialChannel} channel - Session will be generated based on channel.
 * @param {function(session: object)} callback - it will be called on success.
###
generateSession = (channel, callback) ->

  $.ajax
    url      : '/-/video-chat/session'
    method   : 'post'
    dataType : 'JSON'
    data     : { channelId: channel.id }
    success  : callback


###*
 * It makes a request to the backend and gets the token for given session id.
 *
 * TODO: add proper error handling and expireTime support.
 *
 * @param {string} options.sessionId - session id for token to be generated.
 * @param {string=} options.role - role of user in video chat.  (e.g 'publisher', 'moderator')
 * @param {number=} options.expireTime - expiration time for a token. Needs to be lower than 30 days.
 * @param {function(token: string)} callback - callback to be called with token from backend.
 * @see {@link https://tokbox.com/opentok/concepts/token_creation.html}
###
generateToken = (options, callback) ->

  { sessionId, role } = options

  role or= 'publisher'

  $.ajax
    url      : "/-/video-chat/token"
    method   : 'post'
    dataType : 'JSON'
    data     : { role, sessionId }
    success  : (options) -> callback options.token


###*
 * Transforms map with `connectionId`s as keys into a map
 * with nicknames as key.
 *
 * @param {object<string, ParticipantType.Subscriber>} subscribers - keys are connectionIds.
 * @param {ParticipantType.Publisher} publisher
###
toNickKeyedMap = (subscribers, publisher) ->

  map = {}
  map[subscriber.nick] = subscriber  for own cId, subscriber of subscribers
  map[publisher.nick] = publisher  if publisher
  return map


###*
 * Subscribes to given stream, appends the DOM element into given view
 * instance's DOM element.
 *
 * @param {OT.Session} session
 * @param {OT.Stream} stream
 * @param {KDView} view
###
subscribeToStream = (session, stream, view, callbacks) ->

  nick = stream.name
  options =
    height       : '100%'
    width        : '100%'
    insertMode   : 'append'
    style        :
      audioLevelDisplayMode    : 'off'
      buttonDisplayMode        : 'off'
      nameDisplayMode          : 'off'
      videoDisabledDisplayMode : 'on'

  remote.cacheable nick, (err, [account]) ->
    return callbacks.error err  if err
    subscriber = session.subscribe stream, view.getElement(), options, (err) ->
      return callbacks.error err  if err
      subscriber.setStyle 'backgroundImageURI', uri = _getGravatarUri account
      callbacks.success subscriber


###*
 * It creates the `OT.Publisher` instance for sending video/audio.
 *
 * @param {KDView} view - view instance for publisher.
 * @param {objcet=} options - Options to pass to `OT.initPublisher` method
 * @param {string=} options.insertMode
 * @param {string=} options.name
 * @param {objcet=} options.style
 * @return {OT.Publisher} publisher
 * @see {@link https://tokbox.com/opentok/libraries/client/js/reference/OT.html#initPublisher}
###
createPublisher = (view, options = {}, callback) ->

  options.name        or= getNick()
  options.insertMode  or= 'append'
  options.showControls ?= off

  options.height = 265
  options.width  = 325

  publisher = OT.initPublisher view.getElement(), options, (err) ->
    return calback err  if err
    publisher.setStyle 'backgroundImageURI', uri = _getGravatarUri whoami()
    callback null, publisher


###*
 * Subscribes to audio changes of given subscriber. It will call given
 * `callbacks.started` when talking started, and will call `callbacks.stopped`
 * when talking stopped.
 *
 * @param {OT.Subscriber} subscriber
 * @param {object<string, function>} callbacks
###
subscribeToAudioChanges = (subscriber, callbacks) ->

  # this object will be used to keep track of talking activity.
  activity = null

  subscriber.on 'audioLevelUpdated', (event) ->
    now = Date.now()
    # we detected a sound from subscriber
    if event.audioLevel > 0.2
      # create initial activity with talking flag is off when there is no
      # talking activity.
      if not activity
        activity = {timestamp: now, talking: off}

      # if it's already talking just updated the timestamp.
      else if activity.talking
        activity.timestamp = now

      # detected that user is talking more than 1 second.
      # call `started` function of given `callbacks`.
      else if now - activity.timestamp > 1000
        activity.talking = on
        callbacks.started()

    # we have an talking activity record, it's not updated for the past 3 secs.
    # call `stopped` function of given `callbacks`
    else if activity and now - activity.timestamp > 3000
      callbacks.stopped()  if activity.talking
      activity = null


###*
 * get user's gravatar, return the default avatar if user doesn't have an avatar.
 *
 * @param {JAccount} account
 * @param {number} size
###
_getGravatarUri = (account, size = 355) ->

  {hash} = account.profile
  {protocol} = global.location
  defaultUri = "https://koding-cdn.s3.amazonaws.com/square-avatars/default.avatar.#{size}.png"
  return "#{protocol}//gravatar.com/avatar/#{hash}?size=#{size}&d=#{defaultUri}&r=g"


###*
 * Default error signal.
 *
 * @param {object} error
###
_errorSignal = (error) ->

  console.error "signal error #{error.reason}"  if error


module.exports = {
  generateSession
  generateToken
  toNickKeyedMap
  subscribeToStream
  createPublisher
  subscribeToAudioChanges
  _errorSignal
}
