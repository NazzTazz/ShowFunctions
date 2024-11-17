-- This file is part of ShowFunctions -- https://github.com/NazzTazz/ShowFunctions
-- Picker module 
package.preload['ltn12'] = function()
    return require("socket/ltn12")
end

local base = _G
local Obj = require("showfunctions.obj")
local string = require("string")
local table = require("table")
local mime = require("socket/mime")

local _M = {}

local Bitmap = {
    _data = {},
    geometry = {},
    ObjectType = "Image"
}

_M = Bitmap

Bitmap.base64_encode = mime.b64
Bitmap.base64_decode = mime.unb64

-- CONSTANTS

Bitmap.RED, Bitmap.GREEN, Bitmap.BLUE = 1, 2, 3 -- Subpixels offsets

-- Idk why I wrote this, #table should work. To be tested
function Bitmap:count(table)
    local count = 0
    for _ in pairs(table) do
        c = c + 1
    end
    return c
end

-- encapsulate pre-processed bitmap and thumbnail strings into an XML file and import it as UserImage index in the showfile
--
-- @param id        (numeric)   Image slot used for import    
-- @param name      (string)    Image name 
-- @param filename  (string)    Xml image destination Filename

function Bitmap:Store(filename)

    local name = "Generated Bitmap"
    local file = {}
    file.name = filename or "_tmp_bmp"

    if not filename then
        assert(self.Id, "Can't store Bitmap without Pool Id")
    end

    file.path = gma.show.getvar('PATH') .. '/importexport/' .. file.name .. '.xml'

    self:UpdateBitmap()
    self:UpdateThumbnail()

    file.data = io.open(file.path, "w")

    file.data:write('<?xml version="1.0" encoding="utf-8"?>')
    file.data:write(
        '<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" ')
    file.data:write(
        ' xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" ')
    file.data:write('major_vers="3" minor_vers="9" stream_vers="60"><Info datetime="" showfile="" />')
    file.data:write(
        '<UserImage index="1" name="' .. name .. '" hasTransparency="false" width="' .. self.geometry.width ..
            '" height="' .. self.geometry.height .. '"><Image>')
    file.data:write(self._bitmap)
    file.data:write("</Image><Thumbnail>")
    file.data:write(self._thumbnail)
    file.data:write("</Thumbnail></UserImage>\n</MA>")
    file.data:close()

    Cmd('Import "%s.xml" At Image %d /o /nc', file.name, self.Id)

    gma.sleep(0.05)

    if not filename then
        os.remove(gma.show.getvar('PATH') .. '/importexport/' .. file.name .. '.xml')
    end

end

function Bitmap:setDirty()
    self._thumbnail = ''
    self._bitmap = ''
end

-- Creates a base64 String of a 24 bits BRG Bitmap with 8-bit alpha-padding
function Bitmap:UpdateThumbnail(filename)
    if #self._thumbnail then
        return self
    end
    local buffer = ''
    for y = 1, self._height do
        for x = 1, self._width do
            buffer = buffer ..
                         string.char(self._data[y][x][Bitmap.BLUE], self._data[y][x][Bitmap.GREEN],
                    self._data[y][x][Bitmap.RED], 255)
        end
    end
    self._thumbnail = self:base64_encode(buffer)
    return self
end

-- Initializes a new 2D array for pixel data
-- source can be a color or another Bitmap or data table 
function Bitmap:New(args)

    local color, width, height
    local obj = Obj:New(args)
    setmetatable(obj, Bitmap)
    obj:Parse()

    if args.color and type(args.color) == 'table' and #args.color == 3 then -- source is a RGB triplet
        color = args.color
    end
    if not (args.data or args._data) then
        color = {0, 0, 0}
    end -- Black (default)

    if args.data then -- Copy constructor 
        if args.data.geometry then -- args.data as a Bitmap object
            width = args.data.geometry.width
            height = args.data.geometry.height
        else -- args.data is a Table
            width = #args.data[1]
            height = #args.data
        end
    else -- Default constructor
        width = args.width or error()
        height = args.height or error()
    end

    obj.geometry.width = width
    obj.geometry.height = height

    obj:SetData(args.data or color)
    return obj
end

function Bitmap.CreateFromThumbnail(thumb, width, height)

    local expected_length = width * height * 4 -- RGBA for each pixel
    local actual_length = #thumb
    local data = {}

    if expected_length ~= actual_length then
        return nil, 'Thumbnail data length is not coherent'
    end

    local index = 1

    for y = 1, height do

        data[y] = {}

        for x = 1, width do -- ! BGR Format
            data[y][x] = {}
            data[y][x][Bitmap.BLUE] = string.byte(thumb, index)
            data[y][x][Bitmap.GREEN] = string.byte(thumb, index + 1)
            data[y][x][Bitmap.RED] = string.byte(thumb, index + 2)
            index = index + 4 -- Skip 4th byte (Alpha)
        end
    end

    obj = Bitmap:New()
    obj._data = data
    obj._thumbnail = thumb

end

-- Create bitmap file from data table
function Bitmap:UpdateBitmap()

    if #self._bitmap > 0 then
        return self
    end

    local height = count(self._data)
    local width = count(self._data[1])

    local image_size = width * height * 3
    local off_bits, file_size = 54, 54 + image_size

    local header = string.pack("<c2I2I2I4I4I4I4I4I2I2I4I4I4I4I4I4", 'BM', file_size, 0, 0, off_bits, 40, width, height,
        1, 24, 0, image_size, 2835, 2835, 0, 0)

    local bitmap = ''

    for y = 1, height do
        for x = 1, width do
            bitmap = bitmap ..
                         string.char(image[height - y + 1][x][BLUE], image[height - y + 1][x][GREEN],
                    image[height - y + 1][x][RED])
        end
    end

    self._bitmap = base64_encode(header .. bitmap)
    return self
    -- _show_import_bitmap(import_show_index, base64_encode(header .. bitmap), export_thumbnail(image), width, height, cachename)
end

function Bitmap.CreateFromFile(filepath)
    local obj = Bitmap:New()
    obj._data = Bitmap.ReadFile(filepath)
    return obj
end

function Bitmap:Rectangle(x1, y1, x2, y2, color)
    for x = x1, x2 do
        for y = y1, y2 do
            self._data[x][y] = color
        end
    end
    self:setDirty()
end

-- Adds a border to an image
function Bitmap:Border(color, size)

    color = color or {255, 255, 255}

    size = size or math.floor(height / 16) - 1

    self:Rectangle(1, 1, size, self._height, color)
    self:Rectangle(self._width - size, 1, self._width, self._height, color)
    self:Rectangle(1, 1, self._width, size, color)
    self:Rectangle(1, self._height - size, self._width, self._height, color)

    self:setDirty()
    return self
end

-- Darkens the image by reducing the RGB values by a specified ratio
function Bitmap:Darken(ratio)

    ratio = ratio or 0.5 -- Default to darkening by 50%

    for y = 1, self.geometry.height do

        for x = 1, self.geometry.width do
            self._data[y][x][Bitmap.RED] = math.floor(self._data[y][x][Bitmap.RED] * ratio)
            self._data[y][x][Bitmap.GREEN] = math.floor(self._data[y][x][Bitmap.GREEN] * ratio)
            self._data[y][x][Bitmap.BLUE] = math.floor(self._data[y][x][Bitmap.BLUE] * ratio)
        end
    end

    self:setDirty()
    return self
end

-- Mix two bitmaps together
function Bitmap:__mul(img1, img2)
    local data

    assert(img1.geometry.height == img2.geometry.height, 'Bitmap:__mul() Error: bitmaps should be same height')
    assert(img1.geometry.width == img2.geometry.width, 'Bitmap:__mul() Error: bitmaps should be same width')

    for y = 1, img1.geometry.height do
        data[y] = {}
        for x = 1, img1.geometry.width do

            local pix1 = img1._data[y][x]
            local pix2 = img2._data[x][y]

            data[y][x][Bitmap.RED] = math.floor(pix1[y][x][Bitmap.RED] * pix2[Bitmap.RED] / 2.55)
            data[y][x][Bitmap.GREEN] = math.floor(pix1[y][x][Bitmap.GREEN] * pix2[Bitmap.GREEN] / 2.55)
            data[y][x][Bitmap.BLUE] = math.floor(pix1[y][x][Bitmap.BLUE] * pix2[Bitmap.BLUE] / 2.55)
        end
    end
    obj = Bitmap:New()
    obj._data = data
    return obj
end

function Bitmap.ReadFile(filepath)
    local file = io.open(filepath, "rb") or error("Couldn't open Bitmap [rb]")

    -- Read the BMP header
    local check = file:read(2)
    if check ~= 'BM' then
        return nil
    end

    -- Skipping unwanted header bytes to get to the width and height:
    file:seek("set", 18) -- Seek to the width height part of header
    local width = string.unpack("I4", file:read(4))
    local height = string.unpack("I4", file:read(4))

    -- Skipping more bytes to reach the start of the pixel data
    file:seek("set", 10) -- Seek to the offset part of the header
    local offset = string.unpack("I4", file:read(4))
    file:seek("set", offset) -- Move to the start of pixel data

    -- Calculate row padding
    local row_padding = (4 - (width * 3 % 4)) % 4
    local data = {}

    for y = height, 1, -1 do
        data[y] = {}
        for x = 1, width do
            local b, g, r = string.unpack("<BBB", file:read(3)) -- BGR Order
            data[y][x] = {}
            data[y][x][Bitmap.RED] = tonumber(r)
            data[y][x][Bitmap.GREEN] = tonumber(g)
            data[y][x][Bitmap.BLUE] = tonumber(b)
        end
        if row_padding > 0 then
            file:read(row_padding) -- Skip padding bytes
        end
    end

    -- Close the file
    file:close()

    return data
end
