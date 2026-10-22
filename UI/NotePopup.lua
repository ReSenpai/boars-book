local _, LB = ...

-- Small window to write, edit or delete one personal note.
local NotePopup = {}
LB.NotePopup = NotePopup

local L = LB.L

local WIDTH, HEIGHT = 400, 296

local function createFrame()
    local frame = LB.Widgets.CreateWindow("LoreBookNoteFrame", WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame.title:SetText(L("NOTE_TITLE"))
    frame.inputHolder, frame.input = LB.CodeBox.Create(frame, WIDTH - 48, 150)
    frame.inputHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
    frame.input:SetMaxLetters(LB.Annotations.MAX_NOTE_LENGTH)
    frame.saveButton = LB.Widgets.Button(frame, L("NOTE_SAVE"), 110, function() NotePopup.Save() end)
    frame.saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
    frame.deleteButton = LB.Widgets.Button(frame, L("NOTE_DELETE"), 110, function() NotePopup.Delete() end)
    frame.deleteButton:SetPoint("RIGHT", frame.saveButton, "LEFT", -8, 0)
    frame.cancelButton = LB.Widgets.Button(frame, L("CANCEL"), 110, function() frame:Hide() end)
    frame.cancelButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    return frame
end

-- options: { book, note? , anchor? = { chapterId, blockId, textOffset }, onChange? }
function NotePopup.Open(options)
    NotePopup.frame = NotePopup.frame or createFrame()
    NotePopup.options = options
    local frame = NotePopup.frame
    frame.input:SetText(options.note and options.note.text or "")
    frame.deleteButton:SetShown(options.note ~= nil)
    frame:Show()
    frame.input:SetFocus()
end

local function finish()
    NotePopup.frame:Hide()
    local onChange = NotePopup.options.onChange
    if onChange then onChange() end
end

function NotePopup.Save()
    local options = NotePopup.options
    local text = NotePopup.frame.input:GetText()
    if options.note then
        if not LB.Annotations.EditNote(LB.store, options.book.bookId, options.note.id, text) then
            LB.Commands.Print(L("ERR_NOTE_EMPTY"))
            return
        end
    else
        local anchor = options.anchor
        local note, err = LB.Annotations.AddNote(LB.store, options.book, anchor.chapterId, anchor.blockId,
            anchor.textOffset, text)
        if not note then
            LB.Commands.Print(L("ERR_" .. err))
            return
        end
    end
    finish()
end

function NotePopup.Delete()
    local options = NotePopup.options
    if options.note then
        LB.Annotations.RemoveNote(LB.store, options.book.bookId, options.note.id)
    end
    finish()
end
