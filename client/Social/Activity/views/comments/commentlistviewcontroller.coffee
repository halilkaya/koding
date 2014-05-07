class CommentListViewController extends KDListViewController
  constructor:->
    super
    @_hasBackgrounActivity = no
    @startListeners()

  instantiateListItems:(items, keepDeletedComments = no)->

    newItems = []

    items.sort (a,b) =>
      a = a.meta.createdAt
      b = b.meta.createdAt
      if a<b then -1 else if a>b then 1 else 0

    for comment, i in items

      nextComment = items[i+1]

      skipComment = no
      if nextComment? and comment.deletedAt
        if Date.parse(nextComment.meta.createdAt) > Date.parse(comment.deletedAt)
          skipComment = yes

      if not nextComment and comment.deletedAt
        skipComment = yes

      skipComment = no if keepDeletedComments

      unless skipComment
        commentView = @getListView().addItem comment
        newItems.push commentView

    return newItems

  startListeners:->
    listView = @getListView()

    listView.on 'ItemWasAdded', (view, index)=>
      view.on 'CommentIsDeleted', ->
        listView.emit "CommentIsDeleted"

    listView.on "AllCommentsLinkWasClicked", (commentHeader)=>

      return if @_hasBackgrounActivity

      # some problems when logged out server doesnt responds
      @utils.wait 5000, -> listView.emit "BackgroundActivityFinished"

      {meta} = listView.getData()

      listView.emit "BackgroundActivityStarted"
      @_hasBackgrounActivity = yes
      @_removedBefore = no
      @fetchRelativeComments 10, meta.createdAt

  fetchCommentsByRange:(from,to,callback)->
    [to,callback] = [callback,to] unless callback
    query = {from,to}
    message = @getListView().getData()

    message.commentsByRange query,(err,comments)=>
      @getListView().emit "BackgroundActivityFinished"
      callback err,comments

  fetchAllComments:(skipCount=3, callback = noop)->

    listView = @getListView()
    listView.emit "BackgroundActivityStarted"
    message = @getListView().getData()
    message.restComments skipCount, (err, comments)=>
      listView.emit "BackgroundActivityFinished"
      listView.emit "AllCommentsWereAdded"
      callback err, comments

  fetchRelativeComments:(_limit = 10, _after, continuous = yes, _sort = 1)->
    listView = @getListView()
    message = @getListView().getData()
    message.fetchRelativeComments limit:_limit, after:_after, sort:_sort, (err, comments)=>

      if not @_removedBefore
        @removeAllItems()
        @_removedBefore = yes

      @instantiateListItems comments[_limit-10...], yes

      if comments.length is _limit
        startTime = comments[comments.length-1].meta.createdAt
        @fetchRelativeComments ++_limit, startTime, continuous, _sort  if continuous
      else
        listView = @getListView()
        listView.emit "BackgroundActivityFinished"
        listView.emit "AllCommentsWereAdded"
        @_hasBackgrounActivity = no

  replaceAllComments:(comments)->
    @removeAllItems()
    @instantiateListItems comments


  reply: (body, callback = noop) ->

    listView = @getListView()
    activity = listView.getData()

    listView.emit "BackgroundActivityStarted"

    KD.singleton("appManager").tell "Activity", "reply", {activity, body}, (err, reply) =>

      return KD.showError err  if err

      if not KD.getSingleton('activityController').flags?.liveUpdates
        listView.addItem reply
        listView.emit "OwnCommentHasArrived"
      else
        listView.emit "OwnCommentWasSubmitted"
      listView.emit "BackgroundActivityFinished"

    KD.mixpanel "Comment activity, success"
    KD.getSingleton("badgeController").checkBadge
      property: "comments", relType: "commenter", source: "JNewStatusUpdate", targetSelf: 1
