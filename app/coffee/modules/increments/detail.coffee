###
# Copyright (C) 2016 Dario Marinoni <marinoni.dario@gmail.com>
# Copyright (C) 2016 Luca Sturaro <hcsturix74@gmail.com>
# Heavily inspired by taiga increments (detail.coffee)
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/increments/detail.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
toString = @.taiga.toString
joinStr = @.taiga.joinStr
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
bindMethods = @.taiga.bindMethods

module = angular.module("savanaIncrements")

#############################################################################
## Increment Detail Controller
#############################################################################

class IncrementDetailController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$log",
        "tgAppMetaService",
        "$tgAnalytics",
        "$tgNavUrls",
        "$translate"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @params, @q, @location,
                  @log, @appMetaService, @analytics, @navUrls, @translate) ->
        bindMethods(@)

        @scope.incrementRef = @params.incrementref
        @scope.sectionName = @translate.instant("ISSUES.SECTION_NAME")
        @.initializeEventHandlers()

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            @._setMeta()
            @.initializeOnDeleteGoToUrl()

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

    _setMeta: ->
        title = @translate.instant("INCREMENT.PAGE_TITLE", {
            incrementRef: "##{@scope.increment.ref}"
            incrementName: @scope.increment.name
            projectName: @scope.project.name
        })
        description = @translate.instant("INCREMENT.PAGE_DESCRIPTION", {
#            incrementStatus: @scope.statusById[@scope.increment.status]?.name or "--"
#            incrementType: @scope.typeById[@scope.increment.type]?.name or "--"
#            incrementSeverity: @scope.severityById[@scope.increment.severity]?.name or "--"
#            incrementPriority: @scope.priorityById[@scope.increment.priority]?.name or "--"
            #incrementDescription: angular.element(@scope.increment.milestone or "").text()
            incrementDescription: angular.element(@scope.increment.description_html or "").text()
        })
        @appMetaService.setAll(title, description)

    initializeEventHandlers: ->
        @scope.$on "attachment:create", =>
            @analytics.trackEvent("attachment", "create", "create attachment on increment", 1)

#        @scope.$on "promote-increment-to-us:success", =>
#            # @analytics.trackEvent("increment", "promoteToUserstory", "promote increment to userstory", 1)
#            @rootscope.$broadcast("object:updated")
#            @.loadIncrement()

        @scope.$on "comment:new", =>
            @.loadIncrement()

        @scope.$on "custom-attributes-values:edit", =>
            @rootscope.$broadcast("object:updated")

    initializeOnDeleteGoToUrl: ->
       ctx = {project: @scope.project.slug}
       if @scope.project.is_increments_activated
           @scope.onDeleteGoToUrl = @navUrls.resolve("project-increments", ctx)
       else
           @scope.onDeleteGoToUrl = @navUrls.resolve("project", ctx)

    loadProject: ->
        return @rs.projects.getBySlug(@params.pslug).then (project) =>
            @scope.projectId = project.id
            @scope.project = project
            @scope.$emit('project:loaded', project)
#            @scope.statusList = project.increment_statuses
#            @scope.statusById = groupBy(project.increment_statuses, (x) -> x.id)
#            @scope.typeById = groupBy(project.increment_types, (x) -> x.id)
#            @scope.typeList = _.sortBy(project.increment_types, "order")
#            @scope.severityList = project.severities
#            @scope.severityById = groupBy(project.severities, (x) -> x.id)
#            @scope.priorityList = project.priorities
#            @scope.priorityById = groupBy(project.priorities, (x) -> x.id)
            return project

    loadIncrement: ->
        return @rs.increments.getByRef(@scope.projectId, @params.incrementref).then (increment) =>
            @scope.increment = increment
            @scope.incrementId = increment.id
            @scope.commentModel = increment

            if @scope.increment.neighbors.previous?.ref?
                ctx = {
                    project: @scope.project.slug
                    ref: @scope.increment.neighbors.previous.ref
                }
                @scope.previousUrl = @navUrls.resolve("project-increments-detail", ctx)

            if @scope.increment.neighbors.next?.ref?
                ctx = {
                    project: @scope.project.slug
                    ref: @scope.increment.neighbors.next.ref
                }
                @scope.nextUrl = @navUrls.resolve("project-increments-detail", ctx)

    loadInitialData: ->
        promise = @.loadProject()
        return promise.then (project) =>
            @.fillUsersAndRoles(project.members, project.roles)
            @.loadIncrement()

    ###
    # Note: This methods (onUpvote() and onDownvote()) are related to tg-vote-button.
    #       See app/modules/components/vote-button for more info
    ###
    onUpvote: ->
        onSuccess = =>
            @.loadIncrement()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.increments.upvote(@scope.incrementId).then(onSuccess, onError)

    onDownvote: ->
        onSuccess = =>
            @.loadIncrement()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.increments.downvote(@scope.incrementId).then(onSuccess, onError)

    ###
    # Note: This methods (onWatch() and onUnwatch()) are related to tg-watch-button.
    #       See app/modules/components/watch-button for more info
    ###
    onWatch: ->
        onSuccess = =>
            @.loadIncrement()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.increments.watch(@scope.incrementId).then(onSuccess, onError)

    onUnwatch: ->
        onSuccess = =>
            @.loadIncrement()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.increments.unwatch(@scope.incrementId).then(onSuccess, onError)

module.controller("IncrementDetailController", IncrementDetailController)



