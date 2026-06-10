import { LightningElement, api } from "lwc";

export default class AttachmentPreviewModal extends LightningElement {
  @api open = false;
  @api title;
  @api url;

  get isImage() {
    const source = this.fileSource();
    return (
      source.endsWith(".png") ||
      source.endsWith(".jpg") ||
      source.endsWith(".jpeg") ||
      source.endsWith(".gif")
    );
  }

  get isPdf() {
    return this.fileSource().endsWith(".pdf");
  }

  get isUnsupported() {
    return this.url && !this.isImage && !this.isPdf;
  }

  cleanUrl() {
    if (!this.url) return "";
    const normalized = this.url.toLowerCase();
    return normalized.includes("?")
      ? normalized.substring(0, normalized.indexOf("?"))
      : normalized;
  }

  fileSource() {
    const title = (this.title || "").toLowerCase();
    return title.includes(".") ? title : this.cleanUrl();
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleOpenNewTab() {
    if (this.url) {
      window.open(this.url, "_blank", "noopener,noreferrer");
    }
  }
}
