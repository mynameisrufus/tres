Tres      = {}
$         = window.jQuery
_         = window._
Backbone  = window.Backbone
JST       = window.JST
$window   = $(window)
$body     = $('body')
make      = Backbone.View.prototype.make

defaultTemplate = _.template("""
  <header></header>
  <h1>Tres</h1>
  <p>Welcome to Tres</p>
""")

# Tres.Device handles/exposes device events (orientation change, accellerometer, etc), screen width, and 
# other hardware-related goodies.
class Device
  constructor : ->
    _.extend @, Backbone.Events
    $window.on 'orientationchange', _.bind @trigger, @, 'orientation:change'

  width       : -> window.outerWidth
  height      : -> window.outerHeight
  orientation : ->

Tres.Device = new Device

# Tres.Screen is the base screen class. So you'll pretty have one of these for each "route" in your app.
class Tres.Screen extends Backbone.View

  # Defaults to using sections for screens
  tagName   : 'section'

  # Ensure one can still declare events in a view without getting in the way of the defaults.
  __events   : 
    # Click/touch on links will trigger pushState, but stay in the app. Except
    # for links with the "outlink" class.
    "click a[href]:not('.outlink')" : 'touchLink'

    # Provide a convenience method `submit` which gets fired when you submit a form in a screen.
    # You can still trap forms normally. This is just a shortcut in case you have 1 form in a screen.
    "submit form"                   : '__submit'

  events    : {}

  initialize : (options = {}) ->
    _.extend @, options

  # Returns the title of the screen, which will only exist if there's a header with a <h1>
  # inside of it.
  title : (title = null) ->
    if title?
      @$el.find('h1').html(title)
    else
      @$el.find('h1').html()

  render : ->
    @$el.html( (@template or defaultTemplate)(@model) )
    @delegateEvents _.extend(@events, @__events)
    @

  # Embeds a Tres.Screen into the <body>. Returns false in case it's already embedded.
  embed : ->
    return false if @embedded
    @render()
    $body.append @el
    @embedded = true
    @

  touchLink : (event) ->
    event.preventDefault()
    Tres.Router.navigate $(event.currentTarget).attr('href'), true

  __submit : (event) ->
    @submit.apply @, arguments
    @$el.find(':focus').blur()

  submit : ->

  # Sets the class "current" to this screen, removing the class from whatever other sections
  # that have it. Call the `active` method in case a screen has one.
  activate : ->
    $body.find('>section').removeClass 'current'
    @$el.addClass 'current'
    @active.apply(@, arguments) if _.isFunction(@active)

class Tres.ListEntry extends Backbone.View
  initialize : (options = {}) ->
    _.extend @, options

  render : ->
    @$el.html( @template(@model) )
    @delegateEvents('click' : 'touch') if _.isFunction(@url)
    @

  touch : (event) ->
    Tres.Router.navigate @url(), true


# Tres.List is a convenience class for rendering lists of things, interactible or not.
class Tres.List extends Backbone.View
  _tagMap :
    'UL'  : 'LI'
    'OL'  : 'LI'
    'DIV' : 'DIV'

  initialize : (options = {}) ->
    _.extend @, options
    @setElement(@el)
    @collection.on 'add',     @__add,    @
    @collection.on 'remove',  @__remove, @
    @collection.on 'reset',   @__addAll, @

  __add : (model) ->
    tag = @entry.tagName or @_tagMap[@$el.get(0).tagName]
    template = new Tres.ListEntry(_.extend(@entry, { tagName : tag, model : model }))
    model.template = template
    @$el.append template.render().el

  __remove : (model) ->
    model.template.remove()

  __addAll : ->
    @$el.empty()
    @collection.each (model) => @__add(model)  

  remove : ->
    @collection.off() if @collection?
    super

class Tres.Form
  constructor : (@$el) ->
  
  fieldset : (filter) ->
    new Tres.Form(@$el.find('fieldset').filter(filter))
      
  attributes : (options = {})->
    attributes = {}
    if options.only?
      inputs = @$el.find("#{options.only} :input[name]")
    else
      inputs = @$el.find(':input[name]')
      _.each inputs, (el) ->
        $el = $(el)
        if $el.is(':checkbox')
          attributes[ $el.attr('name') ] = $el.is(':checked')
        else
          attributes[ $el.attr('name') ] = $el.val()
    attributes
  
  setFromModel : (model) ->
    _.each _.keys(model.attributes), (key) =>
      $el = @$el.find("[name=\"#{key}\"]")
      if $el.is(':checkbox') and model.attributes[key] is true
        $el.attr('checked', 'checked')
      else
        $el.val model.attributes[key]
  
  clear : ->
    _.each @$el.find(':input'), (el) ->
      $el = $(el)
      $el.removeAttr('checked') if $el.is(':checkbox')
      $el.val('')
    @

# Tres.Notifier: handles displaying in-app notifications
Tres.Notifier =
  $el : $(make('ul', id : 'notifications'))

  notify : (message, options = { duration : 5000, type : 'exclamation-sign' }) ->
    @$el.appendTo $body
    $li = $(make('li', { class : "icon-#{options.type}"}, message))
    @$el.append $li
    $li.slideDown 250, =>
      _.delay =>
        $li.slideUp => $li.remove()
      , options.duration

# Just a regular Backbone.Router for now. By default you'll have one for application
class Router extends Backbone.Router

# Make the router it accessible
Tres.Router = new Router

class Tres.App
  constructor : (options = {}) ->
    _.extend @, options

  screens : []

  on : (map = {}) ->
    _.each _.keys(map), (url) =>
      Tres.Router.route url, _.uniqueId('r'), =>
        screen = map[url]
        screen.embed() unless screen.embedded is true
        args = arguments
        _.defer => screen.activate.apply(screen, args)

  boot : (options = {}) ->
    __super = Backbone.history.loadUrl
    Backbone.history.loadUrl = =>
      Tres.Router.before.call(@) if _.isFunction(Tres.Router.before)
      Tres.Router.trigger 'navigate'
      window.scroll(0, 0)
      __super.apply Backbone.history, arguments
    Backbone.history.start(_.extend(options, pushState : true))


window.Tres = Tres