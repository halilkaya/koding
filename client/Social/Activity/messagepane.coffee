class MessagePane extends KDTabPaneView

  constructor: (options = {}, data) ->

    options.type    or= ''
    options.cssClass  = "message-pane #{options.type}"

    super options, data

    channel           = @getData()
    {itemClass, type} = @getOptions()

    @listController = new ActivityListController
      itemClass     : itemClass
      lastToFirst   : yes  if type is 'message'

    @listView = @listController.getView()
    @input    = new ActivityInputWidget {channel}

    @input.on "Submit", (activity) =>

      @listController.addItem activity


  viewAppended: ->

    @addSubView @input
    @addSubView @listView
    @populate()


  populate: ->

    @fetch (err, items) =>

      return KD.showError err  if err

      console.time('populate')
      @listController.hideLazyLoader()
      @listController.listActivities items
      console.timeEnd('populate')


  fetch: (callback)->

    {appManager}            = KD.singletons
    {name, type, channelId} = @getOptions()
    data                    = @getData()
    options                 = {name, type, channelId}

    # if it is a pinned activity we should already have it
    # as the data object here and we pass it as we've fetched it
    if type is 'pinnedActivity'
    then KD.utils.defer -> callback null, [data]
    else appManager.tell 'Activity', 'fetch', options, callback


  refresh: ->

    document.body.scrollTop            = 0
    document.documentElement.scrollTop = 0

    @listController.removeAllItems()
    @listController.showLazyLoader()
    @populate()
