class ActivityListController extends KDListViewController

  {dash} = Bongo

  constructor:(options={}, data)->

    options.startWithLazyLoader  ?= yes
    options.lazyLoaderOptions     = partial : ''
    options.showHeader           ?= yes
    options.scrollView           ?= no
    options.wrapper              ?= no
    options.boxed                ?= yes
    options.itemClass           or= ActivityListItemView
    options.lastToFirst          ?= yes

    options.viewOptions         or= {}
    {viewOptions}                 = options
    viewOptions.cssClass          = KD.utils.curry 'activity-related', viewOptions.cssClass
    viewOptions.comments         ?= yes

    options.noItemFoundWidget    ?= new KDCustomHTMLView
      cssClass : "lazy-loader hidden"
      partial  : "There is no activity."

    super options, data

    @hiddenItems = []


  listActivities: (activities) ->

    @hideLazyLoader()

    return  unless activities.length > 0

    @addItem activity for activity in activities












  # LEGACY

  postIsCreated: (post) =>
    bugTag   = tag for tag in post.subject.tags when tag.slug is "bug"
    subject  = @prepareSubject post
    instance = @addItem subject, 0

    return  unless instance

    if bugTag and not @isMine subject
      instance.hide()
      @hiddenItems.push instance

    liveUpdate = @activityHeader?.liveUpdateToggle.getState().title is 'live'
    if not liveUpdate and not @isMine subject
      instance.hide()
      @hiddenItems.push instance
      @activityHeader.newActivityArrived() unless bugTag

  prepareSubject:(post)->
    {subject} = post
    subject = KD.remote.revive subject
    @bindItemEvents subject
    return subject



  isMine:(activity)->
    id = KD.whoami().getId()
    id? and id in [activity.originId, activity.anchor?.id]


  checkIfLikedBefore:(activityIds)->
    KD.remote.api.CActivity.checkIfLikedBefore activityIds, (err, likedIds)=>
      for activity in @getListView().items when activity.data.getId().toString() in likedIds
        likeView = activity.subViews.first.actionLinks?.likeView
        if likeView
          likeView.setClass "liked"
          likeView._currentState = yes

  addItem:(activity, index, animation) ->
    dataId = activity.getId?() or activity._id or activity.id
    if dataId?
      if @itemsIndexed[dataId]
        log "duplicate entry", activity.bongo_?.constructorName, dataId
      else
        @itemsIndexed[dataId] = activity
        super activity, index, animation

  unhideNewHiddenItems: ->

    @hiddenItems.forEach (item)-> item.show()

    @hiddenItems = []

    unless KD.getSingleton("router").getCurrentPath() is "/Activity"
      KD.getSingleton("activityController").clearNewItemsCount()

  instantiateListItems:(items)->
    newItems = super
    @checkIfLikedBefore (item.getId()  for item in items)
    return newItems

  bindItemEvents: (item) ->
    item.on "TagsUpdated", (tags) ->
      item.tags = KD.remote.revive tags
