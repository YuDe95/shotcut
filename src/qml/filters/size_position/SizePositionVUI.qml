/*
 * Copyright (c) 2014-2018 Meltytech, LLC
 * Author: Dan Dennedy <dan@dennedy.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.1
import Shotcut.Controls 1.0

Flickable {
    property string rectProperty
    property string fillProperty
    property string distortProperty
    property string halignProperty
    property string valignProperty

    width: 400
    height: 200
    interactive: false
    clip: true
    property real zoom: (video.zoom > 0)? video.zoom : 1.0
    property rect filterRect
    property rect startValue: Qt.rect(-profile.width, 0, profile.width, profile.height)
    property rect middleValue: Qt.rect(0, 0, profile.width, profile.height)
    property rect endValue: Qt.rect(profile.width, 0, profile.width, profile.height)

    contentWidth: video.rect.width * zoom
    contentHeight: video.rect.height * zoom
    contentX: video.offset.x
    contentY: video.offset.y

    function getAspectRatio() {
        return (filter.get(fillProperty) === '1' && filter.get(distortProperty) === '0')? producer.sampleAspectRatio : 0.0
    }

    Component.onCompleted: {
        if (!filter.isNew) {
            filterRect = filter.getRect(rectProperty)
            middleValue = filter.getRect(rectProperty, filter.animateIn)
            if (filter.animateIn > 0)
                startValue = filter.getRect(rectProperty, 0)
            if (filter.animateOut > 0)
                endValue = filter.getRect(rectProperty, filter.duration - 1)
        }
        filterRect = filter.getRect(rectProperty, getPosition())
        rectangle.setHandles(filterRect)
        setRectangleControl()
    }

    function mltRectString(rectangle) {
        return '%L1%/%L2%:%L3%x%L4%'
               .arg(rectangle.x / profile.width * 100)
               .arg(rectangle.y / profile.height * 100)
               .arg(rectangle.width / profile.width * 100)
               .arg(rectangle.height / profile.height * 100)
    }

    function getPosition() {
        return producer.position - (filter.in - producer.in)
    }

    function setRectangleControl() {
        var position = getPosition()
        var newValue = filter.getRect(rectProperty, position)
        if (filterRect !== newValue) {
            filterRect = newValue
            rectangle.setHandles(filterRect)
        }
        rectangle.enabled = position <= 0 || (position >= (filter.animateIn - 1) && position <= (filter.duration - filter.animateOut)) || position >= (filter.duration - 1)
    }

    function setFilter(position) {
        var rect = rectangle.rectangle
        filterRect.x = Math.round(rect.x / rectangle.widthScale)
        filterRect.y = Math.round(rect.y / rectangle.heightScale)
        filterRect.width = Math.round(rect.width / rectangle.widthScale)
        filterRect.height = Math.round(rect.height / rectangle.heightScale)
        if (position !== null) {
            if (position <= 0)
                startValue = filterRect
            else if (position >= filter.duration - 1)
                endValue = filterRect
            else
                middleValue = filterRect
        }

        filter.resetAnimation(rectProperty)
        if (filter.animateIn > 0 || filter.animateOut > 0) {
            if (filter.animateIn > 0) {
                filter.set(rectProperty, startValue.x, startValue.y, startValue.width, startValue.height, 1.0, 0)
                filter.set(rectProperty, middleValue.x, middleValue.y, middleValue.width, middleValue.height, 1.0, filter.animateIn - 1)
            }
            if (filter.animateOut > 0) {
                filter.set(rectProperty, middleValue.x, middleValue.y, middleValue.width, middleValue.height, 1.0, filter.duration - filter.animateOut)
                filter.set(rectProperty, endValue.x, endValue.y, endValue.width, endValue.height, 1.0, filter.duration - 1)
            }
        } else {
            filter.set(rectProperty, mltRectString(middleValue))
        }
    }

    DropArea { anchors.fill: parent }

    Item {
        id: videoItem
        x: video.rect.x
        y: video.rect.y
        width: video.rect.width
        height: video.rect.height
        scale: zoom

        RectangleControl {
            id: rectangle
            widthScale: video.rect.width / profile.width
            heightScale: video.rect.height / profile.height
            aspectRatio: getAspectRatio()
            handleSize: Math.max(Math.round(8 / zoom), 4)
            borderSize: Math.max(Math.round(1.33 / zoom), 1)
            onWidthScaleChanged: setHandles(filterRect)
            onHeightScaleChanged: setHandles(filterRect)
            onRectChanged: setFilter(getPosition())
        }
    }

    Connections {
        target: filter
        onChanged: {
            setRectangleControl()
            if (rectangle.aspectRatio !== getAspectRatio()) {
                rectangle.aspectRatio = getAspectRatio()
                rectangle.setHandles(filterRect)
                setFilter(getPosition())
            }
        }
    }

    Connections {
        target: producer
        onPositionChanged: {
            if (filter.animateIn > 0 || filter.animateOut > 0)
                setRectangleControl()
        }
    }
}
