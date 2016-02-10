###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
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
# File: attachment-link.directive.coffee
###

AttachmentLinkDirective = ($parse, lightboxFactory) ->
    link = (scope, el, attrs) ->
        attachment = $parse(attrs.tgAttachmentLink)(scope)

        el.on "click", (event) ->
            if taiga.isImage(attachment.getIn(['file', 'name']))
                event.preventDefault()

                scope.$apply ->
                    lightboxFactory.create('tg-lb-attachment-preview', {
                        class: 'lightbox lightbox-block'
                    }, {
                        file: attachment.get('file')
                        type: 'image'
                    })
            if taiga.isVideo(attachment.getIn(['file', 'name']))
                event.preventDefault()

                scope.$apply ->
                    lightboxFactory.create('tg-lb-attachment-preview', {
                        class: 'lightbox lightbox-block'
                    }, {
                        file: attachment.get('file')
                        type: 'video'
                    })

        scope.$on "$destroy", -> el.off()
    return {
        link: link
    }

AttachmentLinkDirective.$inject = [
    "$parse",
    "tgLightboxFactory"
]

angular.module("taigaComponents").directive("tgAttachmentLink", AttachmentLinkDirective)
