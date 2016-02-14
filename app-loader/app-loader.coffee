window._version = "___VERSION___"

window.taigaConfig = {
    "api": "http://savana.loginto.me/api/v1/",
    "eventsUrl": null,
    "eventsMaxMissedHeartbeats": 5,
    "eventsHeartbeatIntervalTime": 60000,
    "debug": true,
    "defaultLanguage": "en",
    "themes": ["taiga", "material-design", "high-contrast"],
    "defaultTheme": "taiga",
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "maxUploadFileSize": null,
    "contribPlugins": []
}

window.taigaContribPlugins = []

window._decorators = []

window.addDecorator = (provider, decorator) ->
    window._decorators.push({provider: provider, decorator: decorator})

window.getDecorators = ->
    return window._decorators

loadStylesheet = (path) ->
    $('head').append('<link rel="stylesheet" href="' + path + '" type="text/css" />')

loadPlugin = (pluginPath) ->
    return new Promise (resolve, reject) ->
        $.getJSON(pluginPath).then (plugin) ->
            window.taigaContribPlugins.push(plugin)

            if plugin.css
                loadStylesheet(plugin.css)

            #dont' wait for css
            if plugin.js
                ljs.load(plugin.js, resolve)
            else
                resolve()

loadPlugins = (plugins) ->
    promises = []
    _.map plugins, (pluginPath) ->
        promises.push(loadPlugin(pluginPath))

    return Promise.all(promises)

promise = $.getJSON "/conf.json"
promise.done (data) ->
    window.taigaConfig = _.extend({}, window.taigaConfig, data)

promise.always ->
    if window.taigaConfig.contribPlugins.length > 0
        loadPlugins(window.taigaConfig.contribPlugins).then () ->
            ljs.load "/#{window._version}/js/app.js", ->
                angular.bootstrap(document, ['taiga'])
    else
        ljs.load "/#{window._version}/js/app.js", ->
            angular.bootstrap(document, ['taiga'])
