import { LightningElement, api } from 'lwc';

export default class AttachmentPreviewModal extends LightningElement {
    @api open = false;
    @api title;
    @api url;

    get isImage() {
        const clean = this.cleanUrl();
        return clean.endsWith('.png') || clean.endsWith('.jpg') || clean.endsWith('.jpeg') || clean.endsWith('.gif');
    }

    get isPdf() {
        const clean = this.cleanUrl();
        return clean.endsWith('.pdf');
    }

    get isUnsupported() {
        return this.url && !this.isImage && !this.isPdf;
    }

    cleanUrl() {
        if (!this.url) return '';
        const normalized = this.url.toLowerCase();
        return normalized.includes('?') ? normalized.substring(0, normalized.indexOf('?')) : normalized;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOpenNewTab() {
        if (this.url) {
            window.open(this.url, '_blank');
        }
    }
}