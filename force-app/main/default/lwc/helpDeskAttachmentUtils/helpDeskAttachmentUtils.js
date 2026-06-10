const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "webp", "bmp"];

function extensionFromName(name) {
  if (!name || name.indexOf(".") === -1) {
    return "";
  }
  return name.substring(name.lastIndexOf(".") + 1);
}

function resolveIconName(fileType) {
  const type = (fileType || "").toLowerCase();
  if (IMAGE_EXTENSIONS.includes(type)) {
    return "doctype:image";
  }
  if (type === "pdf") {
    return "doctype:pdf";
  }
  if (type === "doc" || type === "docx") {
    return "doctype:word";
  }
  if (type === "xls" || type === "xlsx" || type === "csv") {
    return "doctype:excel";
  }
  if (type === "txt") {
    return "doctype:txt";
  }
  return "doctype:attachment";
}

export function groupMessageAttachments(links = []) {
  const grouped = {};
  links.forEach((link) => {
    const parentId = link.SObjectId__c;
    if (!parentId) {
      return;
    }
    const url = link.AttachmentURL__c || link.InternalAttachmentURL__c;
    const fileType = (
      link.FileType__c ||
      extensionFromName(link.FileName__c) ||
      ""
    ).toLowerCase();
    const attachment = {
      id: link.Id,
      url,
      title: link.FileName__c || link.AttachmentDescription__c || "Anexo",
      isImage: IMAGE_EXTENSIONS.includes(fileType),
      iconName: resolveIconName(fileType)
    };
    if (!grouped[parentId]) {
      grouped[parentId] = [];
    }
    grouped[parentId].push(attachment);
  });
  return grouped;
}

export function formatFileSize(bytes) {
  if (!bytes && bytes !== 0) {
    return "";
  }
  if (bytes === 0) {
    return "0.0 B";
  }
  const sizes = ["B", "KB", "MB", "GB"];
  const index = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, index)).toFixed(1)} ${sizes[index]}`;
}

export function initialsFromName(name, fallback = "U") {
  if (!name) {
    return fallback;
  }
  return name
    .split(" ")
    .map((part) => part.charAt(0))
    .join("")
    .substring(0, 2)
    .toUpperCase();
}