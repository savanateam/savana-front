###
# Copyright (C) 2014-2016 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2016 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2016 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2016 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2016 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2016 Xavi Julian <xavier.julian@kaleidos.net>
#
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
# File: modules/admin/memberships.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
bindOnce = @.taiga.bindOnce
debounce = @.taiga.debounce
bindMethods = @.taiga.bindMethods

module = angular.module("taigaAdmin")


#############################################################################
## Project Roles Controller
#############################################################################

class RolesController extends mixOf(taiga.Controller, taiga.PageMixin, taiga.FiltersMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "tgAppMetaService",
        "$translate"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @params, @q, @location, @navUrls,
                  @appMetaService, @translate) ->
        bindMethods(@)

        @scope.sectionName = "ADMIN.MENU.PERMISSIONS"
        @scope.project = {}
        @scope.anyComputableRole = true

        promise = @.loadInitialData()

        promise.then () =>
            title = @translate.instant("ADMIN.ROLES.PAGE_TITLE", {projectName: @scope.project.name})
            description = @scope.project.description
            @appMetaService.setAll(title, description)

        promise.then null, @.onInitialDataError.bind(@)

    loadProject: ->
        return @rs.projects.getBySlug(@params.pslug).then (project) =>
            if not project.i_am_owner
                @location.path(@navUrls.resolve("permission-denied"))

            @scope.projectId = project.id
            @scope.project = project

            @scope.$emit('project:loaded', project)
            @scope.anyComputableRole = _.some(_.map(project.roles, (point) -> point.computable))

            return project

    loadRoles: ->
        return @rs.roles.list(@scope.projectId).then (roles) =>
            roles = roles.map (role) ->
                role.external_user = false

                return role

            public_permission = {
                "name": @translate.instant("ADMIN.ROLES.EXTERNAL_USER"),
                "permissions": @scope.project.public_permissions,
                "external_user": true
            }

            roles.push(public_permission)

            @scope.roles = roles
            @scope.role = @scope.roles[0]
            return roles

    loadInitialData: ->
        promise = @.loadProject()
        promise.then(=> @.loadRoles())
        return promise

    setRole: (role) ->
        @scope.role = role
        @scope.$broadcast("role:changed", @scope.role)

    delete: ->
        choices = {}
        for role in @scope.roles
            if role.id != @scope.role.id
                choices[role.id] = role.name

        if _.keys(choices).length == 0
            return @confirm.error(@translate.instant("ADMIN.ROLES.ERROR_DELETE_ALL"))

        title = @translate.instant("ADMIN.ROLES.TITLE_DELETE_ROLE")
        subtitle = @scope.role.name
        replacement = @translate.instant("ADMIN.ROLES.REPLACEMENT_ROLE")
        warning = @translate.instant("ADMIN.ROLES.WARNING_DELETE_ROLE")
        return @confirm.askChoice(title, subtitle, choices, replacement, warning).then (response) =>
            onSuccess = =>
                @.loadProject()
                @.loadRoles().finally =>
                    response.finish()
            onError = =>
                @confirm.notify('error')

            return @repo.remove(@scope.role, {moveTo: response.selected}).then onSuccess, onError

    _enableComputable: =>
        onSuccess = =>
            @confirm.notify("success")
            @.loadProject()

        onError = =>
            @confirm.notify("error")
            @scope.role.revert()

        @repo.save(@scope.role).then onSuccess, onError

    _disableComputable: =>
        askOnSuccess = (response) =>
            onSuccess = =>
                response.finish()
                @confirm.notify("success")
                @.loadProject()
            onError = =>
                response.finish()
                @confirm.notify("error")
                @scope.role.revert()
            @repo.save(@scope.role).then onSuccess, onError

        askOnError = (response) =>
            @scope.role.revert()

        title = @translate.instant("ADMIN.ROLES.DISABLE_COMPUTABLE_ALERT_TITLE")
        subtitle = @translate.instant("ADMIN.ROLES.DISABLE_COMPUTABLE_ALERT_SUBTITLE", {
            roleName: @scope.role.name
        })
        message =  @translate.instant("ADMIN.ROLES.DISABLE_COMPUTABLE_ALERT_MESSAGE")
        return @confirm.ask(title, subtitle, message).then askOnSuccess, askOnError

    toggleComputable: debounce 2000, ->
        if not @scope.role.computable
            @._disableComputable()
        else
            @._enableComputable()

module.controller("RolesController", RolesController)


EditRoleDirective = ($repo, $confirm) ->
    link = ($scope, $el, $attrs) ->
        toggleView = ->
            $el.find('.total').toggle()
            $el.find('.edit-role').toggle()

        submit = () ->
            $scope.role.name = $el.find("input").val()

            promise = $repo.save($scope.role)

            promise.then ->
                $confirm.notify("success")

            promise.then null, (data) ->
                $confirm.notify("error")

            toggleView()

        $el.on "click", "a.icon-edit", ->
            toggleView()
            $el.find("input").focus()
            $el.find("input").val($scope.role.name)

        $el.on "click", "a.save", submit

        $el.on "keyup", "input", (event) ->
            if event.keyCode == 13  # Enter key
                submit()
            else if event.keyCode == 27  # ESC key
                toggleView()

        $scope.$on "role:changed", ->
            if $el.find('.edit-role').is(":visible")
                toggleView()

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgEditRole", ["$tgRepo", "$tgConfirm", EditRoleDirective])

RolesDirective =  ->
    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgRoles", RolesDirective)

NewRoleDirective = ($tgrepo, $confirm) ->
    DEFAULT_PERMISSIONS = ["view_project", "view_milestones", "view_us", "view_tasks", "view_issues"]

    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        $scope.$on "$destroy", ->
            $el.off()

        $el.on "click", "a.add-button", (event) ->
            event.preventDefault()
            $el.find(".new").removeClass("hidden")
            $el.find(".new").focus()
            $el.find(".add-button").hide()

        $el.on "keyup", ".new", (event) ->
            event.preventDefault()
            if event.keyCode == 13  # Enter key
                target = angular.element(event.currentTarget)
                newRole = {
                    project: $scope.projectId
                    name: target.val()
                    permissions: DEFAULT_PERMISSIONS
                    order: _.max($scope.roles, (r) -> r.order).order + 1
                    computable: false
                }

                $el.find(".new").addClass("hidden")
                $el.find(".new").val('')

                onSuccess = (role) ->
                    insertPosition = $scope.roles.length - 1
                    $scope.roles.splice(insertPosition, 0, role)
                    $ctrl.setRole(role)
                    $el.find(".add-button").show()
                    $ctrl.loadProject()

                onError = ->
                    $confirm.notify("error")

                $tgrepo.create("roles", newRole).then(onSuccess, onError)

            else if event.keyCode == 27  # ESC key
                target = angular.element(event.currentTarget)
                $el.find(".new").addClass("hidden")
                $el.find(".new").val('')
                $el.find(".add-button").show()

    return {link:link}

module.directive("tgNewRole", ["$tgRepo", "$tgConfirm", NewRoleDirective])


# Use category-config.scss styles
RolePermissionsDirective = ($rootscope, $repo, $confirm, $compile) ->
    resumeTemplate = _.template("""
    <div class="resume-title" translate="<%- category.name %>"></div>
    <div class="summary-role">
        <div class="count"><%- category.activePermissions %>/<%- category.permissions.length %></div>
        <% _.each(category.permissions, function(permission) { %>
            <div class="role-summary-single <% if(permission.active) { %>active<% } %>"
                 title="{{ '<%- permission.name %>' | translate }}"></div>
        <% }) %>
    </div>
    <div class="icon icon-arrow-bottom"></div>
    """)

    categoryTemplate = _.template("""
    <div class="category-config" data-id="<%- index %>">
        <div class="resume">
        </div>
        <div class="category-items">
            <div class="items-container">
            <% _.each(category.permissions, function(permission) { %>
                <div class="category-item" data-id="<%- permission.key %>">
                    <span translate="<%- permission.name %>"></span>
                    <div class="check">
                        <input type="checkbox"
                               <% if(!permission.editable) { %> disabled="disabled" <% } %>
                               <% if(permission.active) { %> checked="checked" <% } %>/>
                        <div></div>
                        <span class="check-text check-yes" translate="COMMON.YES"></span>
                        <span class="check-text check-no" translate="COMMON.NO"></span>
                    </div>
                </div>
            <% }) %>
            </div>
        </div>
    </div>
    """)

    baseTemplate = _.template("""
    <div class="category-config-list"></div>
    """)

    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        generateCategoriesFromRole = (role) ->
            setActivePermissions = (permissions) ->
                return _.map(permissions, (x) -> _.extend({}, x, {active: x["key"] in role.permissions}))

            isPermissionEditable = (permission, role, project) ->
                if role.external_user &&
                   !project.is_private &&
                   permission.key.indexOf("view_") == 0
                    return false
                else
                    return true

            setActivePermissionsPerCategory = (category) ->
                return _.map(category, (cat) ->
                    cat.permissions = cat.permissions.map (permission) ->
                        permission.editable = isPermissionEditable(permission, role, $scope.project)

                        return permission

                    _.extend({}, cat, {
                        activePermissions: _.filter(cat["permissions"], "active").length
                    })
                )

            categories = []

            milestonePermissions = [
                { key: "view_milestones", name: "COMMON.PERMISIONS_CATEGORIES.SPRINTS.VIEW_SPRINTS"}
                { key: "add_milestone", name: "COMMON.PERMISIONS_CATEGORIES.SPRINTS.ADD_SPRINTS"}
                { key: "modify_milestone", name: "COMMON.PERMISIONS_CATEGORIES.SPRINTS.MODIFY_SPRINTS"}
                { key: "delete_milestone", name: "COMMON.PERMISIONS_CATEGORIES.SPRINTS.DELETE_SPRINTS"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.SPRINTS.NAME",
                permissions: setActivePermissions(milestonePermissions)
            })

            userStoryPermissions = [
                { key: "view_us", name: "COMMON.PERMISIONS_CATEGORIES.USER_STORIES.VIEW_USER_STORIES"}
                { key: "add_us", name: "COMMON.PERMISIONS_CATEGORIES.USER_STORIES.ADD_USER_STORIES"}
                { key: "modify_us", name: "COMMON.PERMISIONS_CATEGORIES.USER_STORIES.MODIFY_USER_STORIES"}
                { key: "delete_us", name: "COMMON.PERMISIONS_CATEGORIES.USER_STORIES.DELETE_USER_STORIES"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.USER_STORIES.NAME",
                permissions: setActivePermissions(userStoryPermissions)
            })

            taskPermissions = [
                { key: "view_tasks", name: "COMMON.PERMISIONS_CATEGORIES.TASKS.VIEW_TASKS"}
                { key: "add_task", name: "COMMON.PERMISIONS_CATEGORIES.TASKS.ADD_TASKS"}
                { key: "modify_task", name: "COMMON.PERMISIONS_CATEGORIES.TASKS.MODIFY_TASKS"}
                { key: "delete_task", name: "COMMON.PERMISIONS_CATEGORIES.TASKS.DELETE_TASKS"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.TASKS.NAME" ,
                permissions: setActivePermissions(taskPermissions)
            })

            issuePermissions = [
                { key: "view_issues", name: "COMMON.PERMISIONS_CATEGORIES.ISSUES.VIEW_ISSUES"}
                { key: "add_issue", name: "COMMON.PERMISIONS_CATEGORIES.ISSUES.ADD_ISSUES"}
                { key: "modify_issue", name: "COMMON.PERMISIONS_CATEGORIES.ISSUES.MODIFY_ISSUES"}
                { key: "delete_issue", name: "COMMON.PERMISIONS_CATEGORIES.ISSUES.DELETE_ISSUES"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.ISSUES.NAME",
                permissions: setActivePermissions(issuePermissions)
            })

            wikiPermissions = [
                { key: "view_wiki_pages", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.VIEW_WIKI_PAGES"}
                { key: "add_wiki_page", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.ADD_WIKI_PAGES"}
                { key: "modify_wiki_page", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.MODIFY_WIKI_PAGES"}
                { key: "delete_wiki_page", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.DELETE_WIKI_PAGES"}
                { key: "view_wiki_links", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.VIEW_WIKI_LINKS"}
                { key: "add_wiki_link", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.ADD_WIKI_LINKS"}
                { key: "delete_wiki_link", name: "COMMON.PERMISIONS_CATEGORIES.WIKI.DELETE_WIKI_LINKS"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.WIKI.NAME",
                permissions: setActivePermissions(wikiPermissions)
            })
			
			# Adding Increments permissions
			incrementPermissions = [
                { key: "view_increment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.VIEW_INCREMENTS"}
                { key: "add_increment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.ADD_INCREMENTS"}
                { key: "modify_increment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.MODIFY_INCREMENTS"}
                { key: "delete_increment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.DELETE_INCREMENTS"}
                #{ key: "view_increment_comment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.VIEW_INCREMENT_MEDIA_COMMENTS"}
				#{ key: "modify_increment_comment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.MODIFY_INCREMENT_MEDIA_COMMENTS"}
                #{ key: "add_increment_comment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.ADD_INCREMENT_MEDIA_COMMENTS"}
                #{ key: "delete_increment_comment", name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.DELETE_INCREMENT_MEDIA_COMMENTS"}
            ]
            categories.push({
                name: "COMMON.PERMISIONS_CATEGORIES.INCREMENTS.NAME",
                permissions: setActivePermissions(incrementPermissions)
            })
            return setActivePermissionsPerCategory(categories)

        renderResume = (element, category) ->
            element.find(".resume").html($compile(resumeTemplate({category: category}))($scope))

        renderCategory = (category, index) ->
            html = categoryTemplate({category: category, index: index})
            html = angular.element(html)
            renderResume(html, category)
            return $compile(html)($scope)

        renderPermissions = () ->
            $el.off()
            html = baseTemplate()
            _.each generateCategoriesFromRole($scope.role), (category, index) ->
                html = angular.element(html).append(renderCategory(category, index))

            $el.html(html)
            $el.on "click", ".resume", (event) ->
                event.preventDefault()
                target = angular.element(event.currentTarget)
                target.next().toggleClass("open")

            $el.on "change", ".category-item input", (event) ->
                getActivePermissions = ->
                    activePermissions = _.filter($el.find(".category-item input"), (t) ->
                        angular.element(t).is(":checked")
                    )
                    activePermissions = _.sortBy(_.map(activePermissions, (t) ->
                        permission = angular.element(t).parents(".category-item").data("id")
                    ))

                    if activePermissions.length
                        activePermissions.push("view_project")

                    return activePermissions

                target = angular.element(event.currentTarget)

                $scope.role.permissions = getActivePermissions()

                onSuccess = () ->
                    categories = generateCategoriesFromRole($scope.role)
                    categoryId = target.parents(".category-config").data("id")
                    renderResume(target.parents(".category-config"), categories[categoryId])
                    $rootscope.$broadcast("projects:reload")
                    $confirm.notify("success")
                    $ctrl.loadProject()

                onError = ->
                    $confirm.notify("error")
                    target.prop "checked", !target.prop("checked")
                    $scope.role.permissions = getActivePermissions()

                if $scope.role.external_user
                    $scope.project.public_permissions = $scope.role.permissions
                    $scope.project.anon_permissions = $scope.role.permissions.filter (permission) ->
                        return permission.indexOf("view_") == 0

                    $repo.save($scope.project).then onSuccess, onError
                else
                    $repo.save($scope.role).then onSuccess, onError

        $scope.$on "$destroy", ->
            $el.off()

        $scope.$on "role:changed", ->
            renderPermissions()

        bindOnce($scope, $attrs.ngModel, renderPermissions)

    return {link:link}

module.directive("tgRolePermissions", ["$rootScope", "$tgRepo", "$tgConfirm", "$compile",
                                       RolePermissionsDirective])
