'use strict'

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
angular.module("savanaWavesurfer", []).filter 'hms', ->
  (str) ->
    sec_num = parseInt(str, 10)
    hours = Math.floor(sec_num / 3600)
    minutes = Math.floor((sec_num - (hours * 3600)) / 60)
    seconds = sec_num - (hours * 3600) - (minutes * 60)
    if hours < 10
      hours = '0' + hours
    if minutes < 10
      minutes = '0' + minutes
    if seconds < 10
      seconds = '0' + seconds
    time = minutes + ':' + seconds
    time


class WavesurferController extends taiga.Controller
  @.$inject = [
    "$scope"
  ]

  constructor: (@scope) ->
    @.initWavesurferJs = initWavesurferJs
    @.getAudioElement = getAudioElement


  getVersion: ->
    if window.wavesurfer and window.wavesurfer.VERSION then window.wavesurfer.VERSION else '0.0.0'

  getAudioElement: (element, attr) ->
    return

  initWavesurferJs: ->
    return

module.controller("WavesurferController", WavesurferController)

##########################################################
### Now directives, videojs, container     ### ############
##########################################################

WavesurferDirective = ($interval, $window) ->
  uniqueId = 1

  postWsLink = (scope, element, ctrl) ->
    id = uniqueId++
    scope.uniqueId = 'waveform_' + id
    scope.wavesurfer = Object.create(WaveSurfer)
    scope.playing = false
    scope.volume_level = $window.sessionStorage.audioLevel or 50

    # TODO: Refactor here, move all these to a dedicated controller
    # updating volume slider value
    scope.updateSlider = ->
      $('#volume').slider
        min: 0
        max: 100
        value: scope.volume_level
        range: 'min'
        animate: true
        slide: (event, ui) ->
          scope.volume_level = $window.sessionStorage.audioLevel = ui.value
          scope.wavesurfer.setVolume scope.volume_level / 100
          return
      return

    waveform = element.children()[0].children[0].children[4]

    # initialize the wavesurfer
    scope.options = _.extend({ container: waveform }, scope.options)
    scope.wavesurfer.init scope.options
    scope.updateSlider()
    scope.wavesurfer.load scope.url
    scope.moment = '0'

    # on ready
    scope.wavesurfer.on 'ready', ->
      scope.length = Math.floor(scope.wavesurfer.getDuration()).toString()
      $interval (->
        scope.moment = Math.floor(scope.wavesurfer.getCurrentTime()).toString()
        return
      ), parseFloat(scope.playrate) * 1000
      return

    # what to be done on finish playing
    scope.wavesurfer.on 'finish', ->
      scope.playing = false
      return
    # play/pause action

    scope.playpause = ->
      scope.wavesurfer.playPause()
      scope.playing = !scope.playing
      return

    scope.ff = ->
      scope.wavesurfer.skipForward()
      return

    scope.bw = ->
      scope.wavesurfer.skipBackward()
      return

    return

  return {
    restrict : 'AE',
      scope    : {
          url     : '=',
          options : '='
      },
      template :
        '<div class="row">' +
            '<div class="col-xs-12 wave-control-wrap">' +
                '<button class="bw-btn" ng-click="bw()">' +
                '</button>' +
                '<button ng-class="{\'play-btn\': !playing, \'pause-btn\': playing}" ng-click="playpause()">' +
                '</button>' +
                '<button class="ff-btn" ng-click="ff()">' +
                '</button>' +
                '<span class="sound-duration pull-left">' +
                    '<span>{{moment | hms}}</span> / <span>{{length | hms}}</span>' +
                '</span>' +
                '<div class="waveform" id="{{::uniqueId}}">' +
                '</div>' +
                '<span ng-class="{\'volume-100\' : volume_level > 50, \'volume-50\' : volume_level > 0 && volume_level <= 50, \'volume-0\' : volume_level === 0}" id="player">' +
                    '<span class="audio-volume" id="volume" style="width: 75%">' +
                    '</span>' +
                '</span>' +
            '</div>' +
        '</div>',
      link : postWsLink
  }

module.directive("WavesurferDirective", ["$interval", "$window", WavesurferDirective])
