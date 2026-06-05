import {
  formatFileSize,
  groupMessageAttachments,
  initialsFromName
} from "c/helpDeskAttachmentUtils";

describe("helpDeskAttachmentUtils", () => {
  it("groups attachments by message and resolves their presentation", () => {
    const grouped = groupMessageAttachments([
      {
        Id: "a01",
        SObjectId__c: "a10",
        FileName__c: "evidencia.png",
        AttachmentURL__c: "https://files.example/evidencia.png"
      },
      {
        Id: "a02",
        SObjectId__c: "a10",
        FileName__c: "relatorio.pdf",
        InternalAttachmentURL__c: "/internal/relatorio.pdf"
      }
    ]);

    expect(grouped.a10).toHaveLength(2);
    expect(grouped.a10[0]).toMatchObject({
      isImage: true,
      iconName: "doctype:image"
    });
    expect(grouped.a10[1]).toMatchObject({
      isImage: false,
      iconName: "doctype:pdf"
    });
  });

  it("formats file size and initials consistently", () => {
    expect(formatFileSize(0)).toBe("0.0 B");
    expect(formatFileSize(1024)).toBe("1.0 KB");
    expect(initialsFromName("Maria Silva")).toBe("MS");
    expect(initialsFromName("", "C")).toBe("C");
  });
});
