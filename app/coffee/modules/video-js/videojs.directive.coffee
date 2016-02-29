###*
# @ngdoc overview
# @name vjsVideoApp
# @description
# # vjsVideoApp
#
# Main module of the application.
###

taiga = @.taiga

# TODO: create the module first, add it to resource file
module = angular.module("savanaVideojs")


class VideoJsController extends taiga.Controller
  @.$inject = [
    "$scope"
  ]

  constructor: (@scope) ->
    @scope.initVideoJs = initVideoJs
    @scope.getVidElement = getVidElement

  getVersion: ->
    if window.videojs and window.videojs.VERSION then window.videojs.VERSION else '0.0.0'


  getVidElement: (element, isContainer) ->
    vid = null
    videos = undefined
    if !window.videojs
      throw new Error('video.js was not found!')
    if isContainer
      videos = element[0].getElementsByTagName('video')
      if videos.length == 0
        throw new Error('video tag must be defined within container directive!')
      else if videos.length > 1
        throw new Error('only one video can be defined within the container directive!')
      vid = videos[0]
    else
      if element[0].nodeName == 'VIDEO'
        vid = element[0]
      else
        throw new Error('directive must be attached to a video tag!')
    vid

# TODO: This is useful for user and promise, child class for annotator?
# loadInitialData: ->
# promise = @.loadProject()
# return promise.then (project) =>
# @.fillUsersAndRoles(project.members, project.roles)
# @.fillUsersAndRoles(project.members, project.roles)
# @.initializeSubscription()
# return @.loadIssues()


  applyRatio: (el, ratioVal) ->
    ratio = ratioVal
    style = document.createElement('style')

    parseRatio = (r) ->
      tokens = r.split(':')
      tokenErrorMsg = 'the ratio must either be "wide", "standard" or ' + 'decimal values in the format of w:h'
      #if invalid ratio throw an error
      if tokens.length != 2
        throw new Error(tokenErrorMsg)
      #confirm that both tokens are numbers
      if isNaN(tokens[0]) or isNaN(tokens[1])
        throw new Error(tokenErrorMsg)
      #confirm that the width or height is not zero
      if Number(tokens[0]) == 0 or Number(tokens[1]) == 0
        throw new Error('neither the width or height ratio can be zero!')
      Number(tokens[1]) / Number(tokens[0]) * 100

    genContainerId = (element) ->
      container = element[0].querySelector('.vjs-tech')
      vjsId = undefined
      if container
        vjsId = 'vjs-container-' + container.getAttribute('id')
      else
        #vjsId = 'vjs-container-default';
        throw new Error('Failed to find instance of video-js class!')
      #add generated id to container
      element[0].setAttribute 'id', vjsId
      vjsId

    containerId = undefined
    ratioPercentage = undefined
    css = undefined
    #if ratio isn't defined lets default to wide screen
    if !ratio
      ratio = '16:9'
    switch ratio
      when 'wide'
        ratio = '16:9'
      when 'standard'
        ratio = '4:3'
    containerId = genContainerId(el)
    ratioPercentage = parseRatio(ratio)
    css = [
      '#'
      containerId
      ' '
      '.video-js {padding-top:'
      ratioPercentage
      '%;}\n'
      '.vjs-fullscreen {padding-top: 0px;}'
    ].join('')
    style.type = 'text/css'
    style.rel = 'stylesheet'
    if style.styleSheet
      style.styleSheet.cssText = css
    else
      style.appendChild document.createTextNode(css)
    el[0].appendChild style
    return

  generateMedia = (ctrl, mediaChangedHandler) ->
    errMsgNoValid = 'a sources and/or tracks element must be ' + 'defined for the vjs-media attribute'
    errMsgNoSrcs = 'sources must be an array of objects with at ' + 'least one item'
    errMsgNoTrks = 'tracks must be an array of objects with at ' + 'least one item'
    div = undefined
    curDiv = undefined
    #check to see if vjsMedia is defined
    if !ctrl.vjsMedia
      return
    #if sources and tracks aren't defined, throw an error
    if !ctrl.vjsMedia.sources and !ctrl.vjsMedia.tracks
      throw new Error(errMsgNoValid)
    #verify sources and tracks are arrays if they are defined
    if ctrl.vjsMedia.sources and !(ctrl.vjsMedia.sources instanceof Array)
      throw new Error(errMsgNoSrcs)
    if ctrl.vjsMedia.tracks and !(ctrl.vjsMedia.tracks instanceof Array)
      throw new Error(errMsgNoTrks)
    #build DOM elements for sources and tracks as children to a div
    div = document.createElement('div')
    if ctrl.vjsMedia.sources
      ctrl.vjsMedia.sources.forEach (curObj) ->
        curDiv = document.createElement('source')
        curDiv.setAttribute 'src', curObj.src or ''
        curDiv.setAttribute 'type', curObj.type or ''
        div.appendChild curDiv
        return
    if ctrl.vjsMedia.tracks
      ctrl.vjsMedia.tracks.forEach (curObj) ->
        curDiv = document.createElement('track')
        curDiv.setAttribute 'kind', curObj.kind or ''
        curDiv.setAttribute 'label', curObj.label or ''
        curDiv.setAttribute 'src', curObj.src or ''
        curDiv.setAttribute 'srclang', curObj.srclang or ''
        #check for default flag
        if curObj.default == true
          curDiv.setAttribute 'default', ''
        div.appendChild curDiv
        return
    #invoke callback
    mediaChangedHandler.call undefined, element: div
    return

  initVideoJs: (vid, params, element, mediaChangedHandler) ->
    opts = params.vjsSetup or {}
    ratio = params.vjsRatio
    isValidContainer = if element[0].nodeName != 'VIDEO' and !getVersion().match(/^5\./) then true else false
    mediaWatcher = undefined
    if !window.videojs
      return null
    #override poster settings if defined in vjsMedia
    if params.vjsMedia and params.vjsMedia.poster
      opts.poster = params.vjsMedia.poster
    #generate any defined sources or tracks
    generateMedia params, mediaChangedHandler
    #watch for changes to vjs-media
    mediaWatcher = @scope.$watch((->
        params.vjsMedia
      ), (newVal, oldVal) ->
        if newVal and !angular.equals(newVal, oldVal)
          #deregister watcher
          mediaWatcher()
          if isValidContainer
            window.videojs(vid).dispose()
            @scope.$emit 'vjsVideoMediaChanged'
          else
            @scope.$emit 'vjsVideoMediaChanged'
        return
    )
    # bootstrap videojs
    window.videojs vid, opts, ->
      if isValidContainer
        applyRatio element, ratio
      #emit ready event with reference to video
      @scope.$emit 'vjsVideoReady',
        id: vid.getAttribute('id')
        vid: this
        player: this
        controlBar: @controlBar
      return

    #dispose of videojs before destroying directive
    @scope.$on '$destroy', ->
      window.videojs(vid).dispose()
      return
      return

module.controller("VideoJsController", VideoJsController)

##########################################################
### Now directives, videojs, container     ### ############
##########################################################

VideoJSDirective = ($compile, $timeout) ->
  postLink = (scope, element, attrs, ctrl, transclude) ->
    vid = undefined
    parentContainer = undefined
    origContent = undefined
    compiledEl = undefined

    mediaChangedHandler = (e) ->
      #remove any inside contents
      element.children().remove()
      #add generated sources and tracks
      element.append e.element.childNodes
      return

    init = ->
      vid = ctrl.getVidElement(element)
      #check if video.js version 5.x is running
      if getVersion().match(/^5\./)
        #if vjsRatio is defined,
        #add it to the vjsSetup options
        if ctrl.vjsRatio
          if !ctrl.vjsSetup
            ctrl.vjsSetup = {}
        ctrl.vjsSetup.aspectRatio = ctrl.vjsRatio

      #attach transcluded content
      transclude (content) ->
        element.append content
        #now that the transcluded content is injected
        #initialize video.js
        ctrl.initVideoJs vid, ctrl, element, mediaChangedHandler
        return
      return

    origContent = element.clone()

    #we need to wrap the video inside of a div
    #for easier DOM management
    if !element.parent().hasClass('vjs-video-wrap')
      element.wrap '<div class="vjs-video-wrap"></div>'
    parentContainer = element.parent()

    scope.$on 'vjsVideoMediaChanged', ->
      #retreive base element that video.js creates
      staleChild = parentContainer.children()[0]
      #remove current directive instance
      #destroy will trigger a video.js dispose
      $timeout ->
        scope.$destroy()
        return
      #compile the new directive and add it to the DOM
      compiledEl = origContent.clone()
      parentContainer.append compiledEl
      #it is key to pass in the parent scope to the directive
      compiledEl = $compile(compiledEl)(scope.$parent)
      #remove original element created by video.js
      staleChild.remove()
      return
    init()
    return

  #TODO: Check better scope here....
  return {
  restrict: 'A'
  transclude: true
  scope: {
    vjsSetup: '=?'
    vjsRatio: '@'
    vjsMedia: '=?'
  }
  controller: 'VideoJsController'
  controllerAs: 'vjsCtrl'
  bindToController: true
  link: postLink
  }


module.directive("VideoJSDirective", ["$compile", "$timeout", VideoJSDirective])


VideoJSContainerDirective = ($compile, $timeout) ->

  postLinkContainer = (scope, element, attrs, ctrl, transclude) ->
    vid = undefined
    origContent = undefined

    mediaChangedHandler = (e) ->
      vidEl = element[0].querySelector('video')
      if vidEl
        #remove any inside contents
        while vidEl.firstChild
          vidEl.removeChild vidEl.firstChild
        #add generated sources and tracks
        while e.element.childNodes.length > 0
          vidEl.appendChild e.element.childNodes[0]
      return

    init = ->
      vid = ctrl.getVidElement(element, true)
      #we want to confirm that the vjs-video directive or
      #any corresponding attributes are not defined on the
      #internal video element
      if vid.getAttribute('vjs-video') != null
        throw new Error('vjs-video should not be used on the video ' + 'tag when using vjs-video-container!')
      #we also want to make sure that no vjs-* attributes
      #are included on the internal video tag
      if vid.getAttribute('vjs-setup') != null or vid.getAttribute('vjs-media') != null or vid.getAttribute('vjs-ratio') != null
        throw new Error('directive attributes should not be used on ' + 'the video tag when using vjs-video-container!')
      #check if video.js version 5.x is running
      if ctrl.getVersion().match(/^5\./)
        if ctrl.vjsRatio
          if !ctrl.vjsSetup
            ctrl.vjsSetup = {}
          ctrl.vjsSetup.aspectRatio = ctrl.vjsRatio
      else
        #set width and height of video to auto
        vid.setAttribute 'width', 'auto'
        vid.setAttribute 'height', 'auto'
      #bootstrap video js
      ctrl.initVideoJs vid, ctrl, element, mediaChangedHandler
      return

    #save original content
    transclude (content) ->
      origContent = content.clone()
      return
    scope.$on 'vjsVideoMediaChanged', ->
      #replace element children with orignal content
      element.children().remove()
      element.append origContent.clone()
      init()
      return
    init()
    return

  return {
    restrict: 'AE',
    transclude: true,
    template: '<div class="vjs-directive-container"><div ng-transclude></div></div>',
    scope: {
      vjsSetup: '=?',
      vjsRatio: '@',
      vjsMedia: '=?'
    },
    controller: 'VjsVideoController',
    controllerAs: 'vjsCtrl',
    bindToController: true,
    link: postLinkContainer
  }