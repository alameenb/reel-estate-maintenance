import { createElement } from 'lwc';
import MaintenanceRequestIntake from 'c/maintenanceRequestIntake';
import getIntakeConfig from '@salesforce/apex/MaintenanceRequestIntakeController.getIntakeConfig';
import submitRequest from '@salesforce/apex/MaintenanceRequestIntakeController.submitRequest';

jest.mock('@salesforce/apex/MaintenanceRequestIntakeController.getIntakeConfig', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/MaintenanceRequestIntakeController.submitRequest', () => ({ default: jest.fn() }), { virtual: true });

const CONFIG = { categories: [{ label: 'Plumbing', value: 'Plumbing' }], mandatoryFields: ['name', 'email', 'street', 'postalCode', 'category', 'description'],
    allowedExtensions: ['jpg', 'pdf'], maxFileSizeKb: 1, maxFileCount: 2 };
const flush = () => new Promise((r) => setTimeout(r, 0));

async function mount() {
    getIntakeConfig.mockResolvedValue(CONFIG);
    const el = createElement('c-maintenance-request-intake', { is: MaintenanceRequestIntake });
    document.body.appendChild(el);
    await flush();
    return el;
}
const q = (el, f) => el.shadowRoot.querySelector(`[data-field="${f}"]`);
function fillAll(el) {
    q(el, 'name').reportValidity = () => true;
    el.shadowRoot.querySelectorAll('[data-field]').forEach((i) => { i.reportValidity = () => true; i.setCustomValidity = jest.fn(); });
}

describe('c-maintenance-request-intake', () => {
    afterEach(() => { while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); } jest.clearAllMocks(); });

    it('renders categories and required markers from config', async () => {
        const el = await mount();
        expect(q(el, 'category').options).toEqual(CONFIG.categories);
        expect(q(el, 'name').required).toBe(true);
        expect(q(el, 'phone').required).toBe(false);
        expect(el.shadowRoot.querySelector('[aria-live="assertive"]')).not.toBeNull();
    });

    it('blocks submission when a required field is invalid', async () => {
        const el = await mount();
        el.shadowRoot.querySelectorAll('[data-field]').forEach((i) => { i.reportValidity = () => i.dataset.field !== 'name'; });
        el.shadowRoot.querySelector('.submit').click();
        await flush();
        expect(submitRequest).not.toHaveBeenCalled();
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('correct the highlighted');
    });

    it('rejects bad file type, oversize file and too many files', async () => {
        const el = await mount();
        const files = [new File(['x'], 'a.exe'), new File(['x'.repeat(5000)], 'big.pdf'), new File(['x'], 'c.jpg')];
        const input = q(el, 'files');
        Object.defineProperty(input, 'files', { value: files });
        input.dispatchEvent(new CustomEvent('change'));
        await flush();
        const msg = el.shadowRoot.querySelector('.file-error').textContent;
        expect(msg).toContain('up to 2 files');
        expect(msg).toContain('a.exe: file type not allowed');
        expect(msg).toContain('big.pdf: larger than 1 KB');
    });

    it('shows the reference number on success', async () => {
        submitRequest.mockResolvedValue('00001234');
        const el = await mount();
        fillAll(el);
        el.shadowRoot.querySelector('.submit').click();
        await flush(); await flush();
        expect(el.shadowRoot.querySelector('.reference').textContent).toBe('00001234');
    });

    it('maps server field errors onto inputs and the summary', async () => {
        submitRequest.mockRejectedValue({ body: { message: JSON.stringify({ email: 'Enter a valid email address.' }) } });
        const el = await mount();
        fillAll(el);
        el.shadowRoot.querySelector('.submit').click();
        await flush(); await flush();
        expect(q(el, 'email').setCustomValidity).toHaveBeenCalledWith('Enter a valid email address.');
        expect(el.shadowRoot.querySelector('.summary').textContent).toContain('Email: Enter a valid email address.');
    });
});
