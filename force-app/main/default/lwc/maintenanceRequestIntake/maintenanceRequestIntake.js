import { LightningElement } from 'lwc';
import getIntakeConfig from '@salesforce/apex/MaintenanceRequestIntakeController.getIntakeConfig';
import submitRequest from '@salesforce/apex/MaintenanceRequestIntakeController.submitRequest';

const EMPTY = { name: '', email: '', phone: '', street: '', city: '', postalCode: '', category: '', description: '', preferredAppointment: '' };
const FIELD_LABELS = { name: 'Full name', email: 'Email', phone: 'Phone', street: 'Street address', city: 'Suburb', postalCode: 'Postcode',
    category: 'Issue category', description: 'Description', preferredAppointment: 'Preferred appointment', files: 'Attachments', form: 'Form' };

export default class MaintenanceRequestIntake extends LightningElement {
    form = { ...EMPTY };
    files = [];
    categories = [];
    mandatory = [];
    allowedExtensions = [];
    maxFileSizeKb = 1024;
    maxFileCount = 3;
    loading = true;
    submitted = false;
    reference;
    errorSummary = '';
    fileError = '';

    connectedCallback() {
        getIntakeConfig()
            .then((cfg) => {
                this.categories = cfg.categories || [];
                this.mandatory = cfg.mandatoryFields || [];
                this.allowedExtensions = cfg.allowedExtensions || [];
                this.maxFileSizeKb = cfg.maxFileSizeKb;
                this.maxFileCount = cfg.maxFileCount;
            })
            .catch(() => { this.errorSummary = 'The form could not load. Please refresh the page.'; })
            .finally(() => { this.loading = false; });
    }

    get req() {
        const r = {};
        Object.keys(EMPTY).forEach((k) => { r[k] = this.mandatory.includes(k); });
        return r;
    }
    get accept() { return this.allowedExtensions.map((e) => '.' + e).join(','); }
    get fileLabel() {
        return `Photos or documents (up to ${this.maxFileCount} files, ${this.maxFileSizeKb} KB each: ${this.allowedExtensions.join(', ')})`;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.detail.value };
        event.target.setCustomValidity('');
    }

    handleFiles(event) {
        const picked = Array.from(event.target.files || []);
        this.fileError = '';
        const problems = [];
        if (picked.length > this.maxFileCount) { problems.push(`You can attach up to ${this.maxFileCount} files.`); }
        const ok = [];
        picked.slice(0, this.maxFileCount).forEach((f) => {
            const ext = (f.name.split('.').pop() || '').toLowerCase();
            if (this.allowedExtensions.length && !this.allowedExtensions.includes(ext)) { problems.push(`${f.name}: file type not allowed.`); }
            else if (f.size > this.maxFileSizeKb * 1024) { problems.push(`${f.name}: larger than ${this.maxFileSizeKb} KB.`); }
            else { ok.push(f); }
        });
        this.fileError = problems.join(' ');
        return Promise.all(ok.map((f) => this.readFile(f))).then((files) => { this.files = files; });
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({ fileName: file.name, base64Data: String(reader.result).split(',')[1] });
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    inputs() { return [...this.template.querySelectorAll('[data-field]')].filter((el) => el.dataset.field !== 'files'); }

    handleSubmit() {
        this.errorSummary = '';
        const valid = this.inputs().reduce((ok, el) => el.reportValidity() && ok, true);
        if (!valid || this.fileError) {
            this.errorSummary = 'Please correct the highlighted fields before submitting.';
            return Promise.resolve();
        }
        this.loading = true;
        const payload = { ...this.form, preferredAppointment: this.form.preferredAppointment || null };
        return submitRequest({ requestJson: JSON.stringify(payload), filesJson: JSON.stringify(this.files) })
            .then((ref) => { this.reference = ref; this.submitted = true; })
            .catch((err) => this.showServerErrors(err))
            .finally(() => { this.loading = false; });
    }

    showServerErrors(err) {
        let map = {};
        try { map = JSON.parse(err?.body?.message || '{}'); } catch (e) { map = { form: 'Something went wrong. Please try again.' }; }
        const messages = [];
        Object.keys(map).forEach((field) => {
            const el = this.template.querySelector(`[data-field="${field}"]`);
            if (el && field !== 'files') { el.setCustomValidity(map[field]); el.reportValidity(); }
            if (field === 'files') { this.fileError = map[field]; }
            messages.push(`${FIELD_LABELS[field] || field}: ${map[field]}`);
        });
        this.errorSummary = messages.length ? messages.join(' ') : 'Something went wrong. Please try again.';
    }

    handleReset() {
        this.form = { ...EMPTY };
        this.files = [];
        this.submitted = false;
        this.reference = undefined;
    }
}
