###
# Copyright (C) 2016 Dario Marinoni <marinoni.dario@gmail.com>
# Copyright (C) 2016 Luca Sturaro <hcsturix74@gmail.com>
# Heavily inspired by taiga issues (list.coffee)
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
# File: modules/increments/list.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
trim = @.taiga.trim
toString = @.taiga.toString
joinStr = @.taiga.joinStr
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
debounceLeading = @.taiga.debounceLeading
startswith = @.taiga.startswith

module = angular.module("savanaIncrements")

#############################################################################
## Increments Controller
#############################################################################

class IncrementsController extends mixOf(taiga.Controller, taiga.PageMixin, taiga.FiltersMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$tgUrls",
        "$routeParams",
        "$q",
        "$tgLocation",
        "tgAppMetaService",
        "$tgNavUrls",
        "$tgEvents",
        "$tgAnalytics",
        "$translate"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @urls, @params, @q, @location, @appMetaService,
                  @navUrls, @events, @analytics, @translate) ->
        @scope.sectionName = "Increments"
        @scope.filters = {}

        if _.isEmpty(@location.search())
            filters = @rs.increments.getFilters(@params.pslug)
            filters.page = 1
            @location.search(filters)
            @location.replace()
            return

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            title = @translate.instant("INCREMENTS.PAGE_TITLE", {projectName: @scope.project.name})
            description = @translate.instant("INCREMENTS.PAGE_DESCRIPTION", {
                projectName: @scope.project.name,
                projectDescription: @scope.project.description
            })
            @appMetaService.setAll(title, description)

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

        @scope.$on "incrementform:new:success", =>
            @analytics.trackEvent("increment", "create", "create increments on increments list", 1)
            @.loadIncrements()

    initializeSubscription: ->
        routingKey = "changes.project.#{@scope.projectId}.increments"
        @events.subscribe @scope, routingKey, (message) =>
            @.loadIncrements()

    storeFilters: ->
        @rs.increments.storeFilters(@params.pslug, @location.search())

    loadProject: ->
        return @rs.projects.getBySlug(@params.pslug).then (project) =>
			# FIXME: check permission denied for increments and not increments, we are surviving
            if not project.is_issues_activated
                @location.path(@navUrls.resolve("permission-denied"))

            @scope.projectId = project.id
            @scope.project = project
            @scope.$emit('project:loaded', project)

            # @scope.incrementStatusById = groupBy(project.increment_statuses, (x) -> x.id)
            # @scope.incrementStatusList = _.sortBy(project.increment_statuses, "order")
            # @scope.severityById = groupBy(project.severities, (x) -> x.id)
            # @scope.severityList = _.sortBy(project.severities, "order")
            # @scope.priorityById = groupBy(project.priorities, (x) -> x.id)
            # @scope.priorityList = _.sortBy(project.priorities, "order")
            # @scope.incrementTypes = _.sortBy(project.increment_types, "order")
            # @scope.incrementTypeById = groupBy(project.increment_types, (x) -> x.id)

            return project

    getUrlFilters: ->
        # filters = _.pick(@location.search(), "page", "tags", "status", "types",
        #                                      "q", "severities", "priorities",
        #                                      "assignedTo", "createdBy", "orderBy")
        filters = _.pick(@location.search(), "page", "tags", "q", "createdBy", "orderBy")
        filters.page = 1 if not filters.page
        return filters

    getUrlFilter: (name) ->
        filters = _.pick(@location.search(), name)
        return filters[name]

    loadMyFilters: ->
        return @rs.increments.getMyFilters(@scope.projectId).then (filters) =>
            return _.map filters, (value, key) =>
                return {id: key, name: key, type: "myFilters", selected: false}

    removeNotExistingFiltersFromUrl: ->
        currentSearch = @location.search()
        urlfilters = @.getUrlFilters()

        for filterName, filterValue of urlfilters
            if filterName == "page" or filterName == "orderBy" or filterName == "q"
                continue

            if filterName == "tags"
                splittedValues = _.map("#{filterValue}".split(","))
            else
                splittedValues = _.map("#{filterValue}".split(","), (x) -> if x == "null" then null else parseInt(x))

            existingValues = _.intersection(splittedValues, _.map(@scope.filters[filterName], "id"))
            if splittedValues.length != existingValues.length
                @location.search(filterName, existingValues.join())

        if currentSearch != @location.search()
           @location.replace()

    markSelectedFilters: (filters, urlfilters) ->
        # Build selected filters (from url) fast lookup data structure
        searchdata = {}
        for name, value of _.omit(urlfilters, "page", "orderBy")
            if not searchdata[name]?
                searchdata[name] = {}

            for val in "#{value}".split(",")
                searchdata[name][val] = true

        isSelected = (type, id) ->
            if searchdata[type]? and searchdata[type][id]
                return true
            return false

        for key, value of filters
            for obj in value
                obj.selected = if isSelected(obj.type, obj.id) then true else undefined

    loadFilters: () ->
        urlfilters = @.getUrlFilters()

        if urlfilters.q
            @scope.filtersQ = urlfilters.q

        # Load My Filters
        promise = @.loadMyFilters().then (myFilters) =>
            @scope.filters.myFilters = myFilters
            return myFilters

        loadFilters = {}
        loadFilters.project = @scope.projectId
        loadFilters.tags = urlfilters.tags
        #loadFilters.status = urlfilters.status
        loadFilters.q = urlfilters.q
        #loadFilters.types = urlfilters.types
        #loadFilters.severities = urlfilters.severities
        #loadFilters.priorities = urlfilters.priorities
        #loadFilters.assigned_to = urlfilters.assignedTo
        loadFilters.owner = urlfilters.createdBy

        # Load default filters data
        promise = promise.then =>
            return @rs.increments.filtersData(loadFilters)

        # Format filters and set them on scope
        return promise.then (data) =>
            usersFiltersFormat = (users, type, unknownOption) =>
                reformatedUsers = _.map users, (t) =>
                    t.type = type
                    t.name = if t.full_name then t.full_name else unknownOption

                    return t

                unknownItem = _.remove(reformatedUsers, (u) -> not u.id)
                reformatedUsers = _.sortBy(reformatedUsers, (u) -> u.name.toUpperCase())
                if unknownItem.length > 0
                    reformatedUsers.unshift(unknownItem[0])
                return reformatedUsers

            choicesFiltersFormat = (choices, type, byIdObject) =>
                _.map choices, (t) ->
                    t.type = type
                    return t

            tagsFilterFormat = (tags) =>
                return _.map tags, (t) ->
                    t.id = t.name
                    t.type = 'tags'
                    return t

            # Build filters data structure
            @scope.filters.status = choicesFiltersFormat(data.statuses, "status", @scope.incrementStatusById)
            # @scope.filters.severities = choicesFiltersFormat(data.severities, "severities", @scope.severityById)
            # @scope.filters.priorities = choicesFiltersFormat(data.priorities, "priorities", @scope.priorityById)
            # @scope.filters.assignedTo = usersFiltersFormat(data.assigned_to, "assignedTo", "Unassigned")
            @scope.filters.createdBy = usersFiltersFormat(data.owners, "createdBy", "Unknown")
            # @scope.filters.types = choicesFiltersFormat(data.types, "types", @scope.incrementTypeById)
            @scope.filters.tags = tagsFilterFormat(data.tags)

            @.removeNotExistingFiltersFromUrl()
            @.markSelectedFilters(@scope.filters, urlfilters)

            @rootscope.$broadcast("filters:loaded", @scope.filters)

    # We need to guarantee that the last petition done here is the finally used
    # When searching by text loadIncrements can be called fastly with different parameters and
    # can be resolved in a different order than generated
    # We count the requests made and only if the callback is for the last one data is updated
    loadIncrementsRequests: 0
    loadIncrements: =>
        @scope.urlFilters = @.getUrlFilters()

        # Convert stored filters to http parameters
        # ready filters (the name difference exists
        # because of some automatic lookups and is
        # the simplest way todo it without adding
        # additional complexity to code.
        @scope.httpParams = {}
        for name, values of @scope.urlFilters
            if name == "orderBy"
                name = "order_by"
            else if name == "createdBy"
                name = "owner"
            @scope.httpParams[name] = values

        promise = @rs.increments.list(@scope.projectId, @scope.httpParams)
        @.loadIncrementsRequests += 1
        promise.index = @.loadIncrementsRequests
        promise.then (data) =>
            if promise.index == @.loadIncrementsRequests
                @scope.increments = data.models
                @scope.page = data.current
                @scope.count = data.count
                @scope.paginatedBy = data.paginatedBy

            return data

        return promise

    loadInitialData: ->
        promise = @.loadProject()
        return promise.then (project) =>
            @.fillUsersAndRoles(project.members, project.roles)
            @.initializeSubscription()
            # @.loadFilters()

            return @.loadIncrements()

    saveCurrentFiltersTo: (newFilter) ->
        deferred = @q.defer()
        @rs.increments.getMyFilters(@scope.projectId).then (filters) =>
            filters[newFilter] = @location.search()
            @rs.increments.storeMyFilters(@scope.projectId, filters).then =>
                deferred.resolve()
        return deferred.promise

    deleteMyFilter: (filter) ->
        deferred = @q.defer()
        @rs.increments.getMyFilters(@scope.projectId).then (filters) =>
            delete filters[filter]
            @rs.increments.storeMyFilters(@scope.projectId, filters).then =>
                deferred.resolve()
        return deferred.promise

    # Functions used from templates
    addNewIncrement: ->
        @rootscope.$broadcast("incrementform:new", @scope.project)

    # addIncrementsInBulk: ->
    #    @rootscope.$broadcast("incrementform:bulk", @scope.projectId)


module.controller("IncrementsController", IncrementsController)

#############################################################################
## Increments Directive
#############################################################################

IncrementsDirective = ($log, $location, $template, $compile) ->
    ## Increments Pagination
    template = $template.get("increment/increment-paginator.html", true)

    linkPagination = ($scope, $el, $attrs, $ctrl) ->
        # Constants
        afterCurrent = 2
        beforeCurrent = 4
        atBegin = 2
        atEnd = 2

        $pagEl = $el.find(".increments-paginator")

        getNumPages = ->
            numPages = $scope.count / $scope.paginatedBy
            if parseInt(numPages, 10) < numPages
                numPages = parseInt(numPages, 10) + 1
            else
                numPages = parseInt(numPages, 10)

            return numPages

        renderPagination = ->
            numPages = getNumPages()

            if numPages <= 1
                $pagEl.hide()
                return
            $pagEl.show()

            pages = []
            options = {}
            options.pages = pages
            options.showPrevious = ($scope.page > 1)
            options.showNext = not ($scope.page == numPages)

            cpage = $scope.page

            for i in [1..numPages]
                if i == (cpage + afterCurrent) and numPages > (cpage + afterCurrent + atEnd)
                    pages.push({classes: "dots", type: "dots"})
                else if i == (cpage - beforeCurrent) and cpage > (atBegin + beforeCurrent)
                    pages.push({classes: "dots", type: "dots"})
                else if i > (cpage + afterCurrent) and i <= (numPages - atEnd)
                else if i < (cpage - beforeCurrent) and i > atBegin
                else if i == cpage
                    pages.push({classes: "active", num: i, type: "page-active"})
                else
                    pages.push({classes: "page", num: i, type: "page"})


            html = template(options)
            html = $compile(html)($scope)

            $pagEl.html(html)

        $scope.$watch "increments", (value) ->
            # Do nothing if value is not logical true
            return if not value

            renderPagination()

        $el.on "click", ".increments-paginator a.next", (event) ->
            event.preventDefault()

            $scope.$apply ->
                $ctrl.selectFilter("page", $scope.page + 1)
                $ctrl.loadIncrements()

        $el.on "click", ".increments-paginator a.previous", (event) ->
            event.preventDefault()
            $scope.$apply ->
                $ctrl.selectFilter("page", $scope.page - 1)
                $ctrl.loadIncrements()

        $el.on "click", ".increments-paginator li.page > a", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            pagenum = target.data("pagenum")

            $scope.$apply ->
                $ctrl.selectFilter("page", pagenum)
                $ctrl.loadIncrements()

    ## Increments Filters
    linkOrdering = ($scope, $el, $attrs, $ctrl) ->
        # Draw the arrow the first time
        currentOrder = $ctrl.getUrlFilter("orderBy") or "created_date"
        if currentOrder
            icon = if startswith(currentOrder, "-") then "icon-arrow-up" else "icon-arrow-bottom"
            colHeadElement = $el.find(".row.title > div[data-fieldname='#{trim(currentOrder, "-")}']")
            colHeadElement.html("#{colHeadElement.html()}<span class='icon #{icon}'></span>")

        $el.on "click", ".row.title > div", (event) ->
            target = angular.element(event.currentTarget)

            currentOrder = $ctrl.getUrlFilter("orderBy")
            newOrder = target.data("fieldname")

            finalOrder = if currentOrder == newOrder then "-#{newOrder}" else newOrder

            $scope.$apply ->
                $ctrl.replaceFilter("orderBy", finalOrder)
                $ctrl.storeFilters()
                $ctrl.loadIncrements().then ->
                    # Update the arrow
                    $el.find(".row.title > div > span.icon").remove()
                    icon = if startswith(finalOrder, "-") then "icon-arrow-up" else "icon-arrow-bottom"
                    target.html("#{target.html()}<span class='icon #{icon}'></span>")

    ## Increments Link
    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()
        linkOrdering($scope, $el, $attrs, $ctrl)
        linkPagination($scope, $el, $attrs, $ctrl)

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgIncrements", ["$log", "$tgLocation", "$tgTemplate", "$compile", IncrementsDirective])


#############################################################################
## Increments Filters Directive
#############################################################################

IncrementsFiltersDirective = ($q, $log, $location, $rs, $confirm, $loading, $template, $translate, $compile, $auth) ->
    template = $template.get("increments/increments-filters.html", true)
    templateSelected = $template.get("increments/increments-filters-selected.html", true)

    link = ($scope, $el, $attrs) ->
        $ctrl = $el.closest(".wrapper").controller()

        selectedFilters = []

        showFilters = (title, type) ->
            $el.find(".filters-cats").hide()
            $el.find(".filter-list").removeClass("hidden")
            $el.find("h2.breadcrumb").removeClass("hidden")
            $el.find("h2 a.subfilter span.title").html(title)
            $el.find("h2 a.subfilter span.title").prop("data-type", type)

        showCategories = ->
            $el.find(".filters-cats").show()
            $el.find(".filter-list").addClass("hidden")
            $el.find("h2.breadcrumb").addClass("hidden")

        initializeSelectedFilters = (filters) ->
            selectedFilters = []
            for name, values of filters
                for val in values
                    selectedFilters.push(val) if val.selected

            renderSelectedFilters(selectedFilters)

        renderSelectedFilters = (selectedFilters) ->
            _.filter selectedFilters, (f) =>
                if f.color
                    f.style = "border-left: 3px solid #{f.color}"

            html = templateSelected({filters:selectedFilters})
            html = $compile(html)($scope)
            $el.find(".filters-applied").html(html)

            if $auth.isAuthenticated() && selectedFilters.length > 0
                $el.find(".save-filters").show()
            else
                $el.find(".save-filters").hide()

        renderFilters = (filters) ->
            _.filter filters, (f) =>
                if f.color
                    f.style = "border-left: 3px solid #{f.color}"

            html = template({filters:filters})
            html = $compile(html)($scope)
            $el.find(".filter-list").html(html)

        getFiltersType = () ->
            return $el.find("h2 a.subfilter span.title").prop('data-type')

        reloadIncrements = () ->
            currentFiltersType = getFiltersType()

            $q.all([$ctrl.loadIncrements(), $ctrl.loadFilters()]).then () ->
                filters = $scope.filters[currentFiltersType]
                renderFilters(_.reject(filters, "selected"))

        toggleFilterSelection = (type, id) ->
            if type == "myFilters"
                $rs.increments.getMyFilters($scope.projectId).then (data) ->
                    myFilters = data
                    filters = myFilters[id]
                    filters.page = 1
                    $ctrl.replaceAllFilters(filters)
                    $ctrl.storeFilters()
                    $ctrl.loadIncrements()
                    $ctrl.markSelectedFilters($scope.filters, filters)
                    initializeSelectedFilters($scope.filters)
                return null

            filters = $scope.filters[type]
            filterId = if type == 'tags' then taiga.toString(id) else id
            filter = _.find(filters, {id: filterId})
            filter.selected = (not filter.selected)

            # Convert id to null as string for properly
            # put null value on url parameters
            id = "null" if id is null

            if filter.selected
                selectedFilters.push(filter)
                $ctrl.selectFilter(type, id)
                $ctrl.selectFilter("page", 1)
                $ctrl.storeFilters()
            else
                selectedFilters = _.reject selectedFilters, (f) ->
                    return f.id == filter.id && f.type == filter.type

                $ctrl.unselectFilter(type, id)
                $ctrl.selectFilter("page", 1)
                $ctrl.storeFilters()

            reloadIncrements()

            renderSelectedFilters(selectedFilters)

            currentFiltersType = getFiltersType()

            if type == currentFiltersType
                renderFilters(_.reject(filters, "selected"))

        # Angular Watchers
        $scope.$on "filters:loaded", (ctx, filters) ->
            initializeSelectedFilters(filters)

        $scope.$on "filters:incrementupdate", (ctx, filters) ->
            html = template({filters:filters.status})
            html = $compile(html)($scope)
            $el.find(".filter-list").html(html)

        selectQFilter = debounceLeading 100, (value, oldValue) ->
            return if value is undefined or  value == oldValue

            $ctrl.replaceFilter("page", null, true)

            if value.length == 0
                $ctrl.replaceFilter("q", null)
                $ctrl.storeFilters()
            else
                $ctrl.replaceFilter("q", value)
                $ctrl.storeFilters()

            reloadIncrements()

        unwatchIncrements = $scope.$watch "increments", (newValue) ->
            if !_.isUndefined(newValue)
                $scope.$watch("filtersQ", selectQFilter)
                unwatchIncrements()

        # Dom Event Handlers
        $el.on "click", ".filters-cats > ul > li > a", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            tags = $scope.filters[target.data("type")]
            renderFilters(_.reject(tags, "selected"))
            showFilters(target.attr("title"), target.data("type"))

        $el.on "click", ".filters-inner > .filters-step-cat > .breadcrumb > .back", (event) ->
            event.preventDefault()
            showCategories($el)

        $el.on "click", ".filters-applied a", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)

            id = target.data("id") or null
            type = target.data("type")
            toggleFilterSelection(type, id)

        $el.on "click", ".filter-list .single-filter", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            target.toggleClass("active")

            id = target.data("id") or null
            type = target.data("type")

            # A saved filter can't be active
            if type == "myFilters"
                target.removeClass("active")

            toggleFilterSelection(type, id)

        $el.on "click", ".filter-list .single-filter .icon-delete", (event) ->
            event.preventDefault()
            event.stopPropagation()

            target = angular.element(event.currentTarget)
            customFilterName = target.parent().data('id')
            title = $translate.instant("INCREMENTS.FILTERS.CONFIRM_DELETE.TITLE")
            message = $translate.instant("INCREMENTS.FILTERS.CONFIRM_DELETE.MESSAGE", {customFilterName: customFilterName})

            $confirm.askOnDelete(title, message).then (askResponse) ->
                promise = $ctrl.deleteMyFilter(customFilterName)
                promise.then ->
                    promise = $ctrl.loadMyFilters()
                    promise.then (filters) ->
                        askResponse.finish()
                        $scope.filters.myFilters = filters
                        renderFilters($scope.filters.myFilters)
                    promise.then null, ->
                        askResponse.finish()
                promise.then null, ->
                    askResponse.finish(false)
                    $confirm.notify("error")


        $el.on "click", ".save-filters", (event) ->
            event.preventDefault()
            renderFilters($scope.filters["myFilters"])
            showFilters("My filters", "myFilters")
            $el.find('.save-filters').hide()
            $el.find('.my-filter-name').removeClass("hidden")
            $el.find('.my-filter-name').focus()
            $scope.$apply()

        $el.on "keyup", ".my-filter-name", (event) ->
            event.preventDefault()
            if event.keyCode == 13
                target = angular.element(event.currentTarget)
                newFilter = target.val()
                currentLoading = $loading()
                    .target($el.find(".new"))
                    .start()
                promise = $ctrl.saveCurrentFiltersTo(newFilter)
                promise.then ->
                    loadPromise = $ctrl.loadMyFilters()
                    loadPromise.then (filters) ->
                        currentLoading.finish()
                        $scope.filters.myFilters = filters

                        currentfilterstype = $el.find("h2 a.subfilter span.title").prop('data-type')
                        if currentfilterstype == "myFilters"
                            renderFilters($scope.filters.myFilters)

                        $el.find('.my-filter-name').addClass("hidden")
                        $el.find('.save-filters').show()

                    loadPromise.then null, ->
                        currentLoading.finish()
                        $confirm.notify("error", "Error loading custom filters")

                promise.then null, ->
                    currentLoading.finish()
                    $el.find(".my-filter-name").val(newFilter).focus().select()
                    $confirm.notify("error", "Filter not saved")

            else if event.keyCode == 27
                $el.find('.my-filter-name').val('')
                $el.find('.my-filter-name').addClass("hidden")
                $el.find('.save-filters').show()

    return {link:link}

module.directive("tgIncrementsFilters", ["$q", "$log", "$tgLocation", "$tgResources", "$tgConfirm", "$tgLoading",
                                     "$tgTemplate", "$translate", "$compile", "$tgAuth", IncrementsFiltersDirective])


#############################################################################
## Increment status Directive (popover for change status)
#############################################################################

IncrementStatusInlineEditionDirective = ($repo, $template, $rootscope) ->
    ###
    Print the status of an Increment and a popover to change it.
    - tg-increment-status-inline-edition: The increment

    Example:

      div.status(tg-increment-status-inline-edition="increment")
        a.increment-status(href="")

    NOTE: This directive need 'incrementStatusById' and 'project'.
    ###
    selectionTemplate = $template.get("increment/increment-status-inline-edition-selection.html", true)

    updateIncrementStatus = ($el, increment, incrementStatusById) ->
        incrementStatusDomParent = $el.find(".increment-status")
        incrementStatusDom = $el.find(".increment-status .increment-status-bind")

        status = '' # incrementStatusById[increment.status]

        if status
            incrementStatusDom.text(status.name)
            incrementStatusDom.prop("title", status.name)
            incrementStatusDomParent.css('color', status.color)

    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()
        increment = $scope.$eval($attrs.tgIncrementStatusInlineEdition)

        $el.on "click", ".increment-status", (event) ->
            event.preventDefault()
            event.stopPropagation()
            $el.find(".pop-status").popover().open()

        $el.on "click", ".status", (event) ->
            event.preventDefault()
            event.stopPropagation()
            target = angular.element(event.currentTarget)

            for filter in $scope.filters.status
                if filter.id == increment.status
                    filter.count--

            increment.status = target.data("status-id")
            $el.find(".pop-status").popover().close()
            updateIncrementStatus($el, increment, $scope.incrementStatusById)

            $scope.$apply () ->
                $repo.save(increment).then ->
                    $ctrl.loadIncrements()

                for filter in $scope.filters.status
                    if filter.id == increment.status
                        filter.count++

                $rootscope.$broadcast("filters:incrementupdate", $scope.filters)

        taiga.bindOnce $scope, "project", (project) ->
			#FIXME: check for project.increment_statuses
            #$el.append(selectionTemplate({ 'statuses':  project.increment_statuses }))
            updateIncrementStatus($el, increment, $scope.incrementStatusById)

            # If the user has not enough permissions the click events are unbinded
#            if project.my_permissions.indexOf("modify_increment") == -1
#                $el.unbind("click")
#                $el.find("a").addClass("not-clickable")

        $scope.$watch $attrs.tgIncrementStatusInlineEdition, (val) =>
            updateIncrementStatus($el, val, $scope.incrementStatusById)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgIncrementStatusInlineEdition", ["$tgRepo", "$tgTemplate", "$rootScope",
                                                IncrementStatusInlineEditionDirective])


#############################################################################
## Increment Owner Directive
#############################################################################

IncrementOwnerInlineEditionDirective = ($repo, $rootscope, $translate) ->
    template = _.template("""
    <img src="<%- imgurl %>" alt="<%- name %>"/>
    <figcaption><%- name %></figcaption>
    """)

    link = ($scope, $el, $attrs) ->
        updateIncrement = (increment) ->
            ctx = {
                name: $translate.instant("COMMON.ASSIGNED_TO.NOT_ASSIGNED"),
                imgurl: "/#{window._version}/images/unnamed.png"
            }

            member = $scope.usersById[increment.owner]
            if member
                ctx.name = member.full_name_display
                ctx.imgurl = member.photo

            $el.find(".avatar").html(template(ctx))
            $el.find(".increment-owner").attr('title', ctx.name)

        $ctrl = $el.controller()
        issue = $scope.$eval($attrs.tgIncrementOwnerInlineEdition)
        updateIncrement(issue)

        $el.on "click", ".increment-owner", (event) ->
            $rootscope.$broadcast("owner:add", issue)

        taiga.bindOnce $scope, "project", (project) ->
            # If the user has not enough permissions the click events are unbinded
            if project.my_permissions.indexOf("modify_increment") == -1
                $el.unbind("click")
                $el.find("a").addClass("not-clickable")

        $scope.$on "owner:added", (ctx, userId, updatedIncrement) =>
            if updatedIncrement.id == issue.id
                updatedIncrement.owner = userId
                $repo.save(updatedIncrement)
                updateIncrement(updatedIncrement)

        $scope.$watch $attrs.tgIncrementOwnerInlineEdition, (val) =>
            updateIncrement(val)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgIncrementOwnerInlineEdition", ["$tgRepo", "$rootScope", "$translate"
                                                    IncrementOwnerInlineEditionDirective])
