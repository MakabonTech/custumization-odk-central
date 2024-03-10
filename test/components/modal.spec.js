import sinon from 'sinon';
import { nextTick } from 'vue';

import Alert from '../../src/components/alert.vue';
import Modal from '../../src/components/modal.vue';

import { mergeMountOptions, mount } from '../util/lifecycle';
import { wait } from '../util/util';

const mountComponent = (options = undefined) =>
  mount(Modal, mergeMountOptions(options, {
    props: { state: true, hideable: true, backdrop: true },
    slots: {
      title: { template: 'Some Title' },
      body: { template: '<p>Some text</p>' }
    }
  }));

describe('Modal', () => {
  it('uses the title slot', () => {
    const modal = mountComponent({
      slots: {
        title: { template: 'foo' }
      }
    });
    modal.get('.modal-title').text().should.equal('foo');
  });

  it('uses the body slot', () => {
    const modal = mountComponent({
      slots: {
        body: { template: '<pre>foo</pre>' }
      }
    });
    modal.get('.modal-body pre').text().should.equal('foo');
  });

  it('shows any alert', () => {
    mountComponent().findComponent(Alert).exists().should.be.true();
  });

  describe('state prop is true', () => {
    it('shows the modal', () => {
      mountComponent({
        props: { state: true },
        attachTo: document.body
      });
      document.body.classList.contains('modal-open').should.be.true();
    });

    it('emits a shown event', () => {
      const modal = mountComponent({
        props: { state: true }
      });
      modal.emitted().shown.should.eql([[]]);
    });
  });

  describe('after the state prop changes to true', () => {
    it('shows the modal', async () => {
      const modal = mountComponent({
        props: { state: false },
        attachTo: document.body
      });
      await modal.setProps({ state: true });
      document.body.classList.contains('modal-open').should.be.true();
    });

    it('hides any alert', async () => {
      const modal = mountComponent({
        props: { state: false }
      });
      modal.vm.$container.alert.info('Some alert');
      await modal.setProps({ state: true });
      modal.should.not.alert();
    });
  });

  describe('after the state prop changes to false', () => {
    it('hides the modal', async () => {
      const modal = mountComponent({
        props: { state: true },
        attachTo: document.body
      });
      await modal.setProps({ state: false });
      document.body.classList.contains('modal-open').should.be.false();
    });

    it('hides an alert that was shown before modal was hidden', async () => {
      const modal = mountComponent({
        props: { state: true }
      });
      modal.vm.$container.alert.info('Some alert');
      await modal.vm.$nextTick();
      await modal.setProps({ state: false });
      modal.should.not.alert();
    });

    it('does not hide an alert that is set as modal is hidden', async () => {
      const modal = mountComponent({
        props: { state: true }
      });
      modal.vm.$container.alert.info('Some alert');
      await modal.setProps({ state: false });
      modal.should.alert();
    });
  });

  it("updates the modal's position after its body changes", async () => {
    const modal = mountComponent({
      slots: {
        body: { template: '<p>Some text</p>' }
      },
      attachTo: document.body
    });
    const bs = sinon.fake(modal.vm.bs);
    modal.setData({ bs });
    modal.vm.$container.alert.info('Some alert');
    await modal.vm.$nextTick();
    modal.get('.modal-body p').element.textContent = 'New text';
    await modal.vm.$nextTick();
    bs.args.should.eql([['handleUpdate'], ['handleUpdate']]);
  });

  describe('size prop', () => {
    it("adds the correct class if the prop is 'large'", () => {
      const modal = mountComponent({
        props: { size: 'large' }
      });
      modal.get('.modal-dialog').classes('modal-lg').should.be.true();
    });

    describe("prop is 'full'", () => {
      it('adds the correct class', () => {
        const modal = mountComponent({
          props: { size: 'full' }
        });
        modal.get('.modal-dialog').classes('modal-full').should.be.true();
      });

      describe('has-scroll class', () => {
        it('adds class if modal vertically overflows viewport', async () => {
          const modal = mountComponent({
            props: { size: 'full' },
            slots: {
              body: { template: '<div style="height: 10000px;"></div>' }
            },
            attachTo: document.body
          });
          await nextTick();
          modal.classes('has-scroll').should.be.true();
        });

        it('does not add class if modal does not overflow', async () => {
          const modal = mountComponent({
            props: { size: 'full' },
            attachTo: document.body
          });
          await nextTick();
          modal.classes('has-scroll').should.be.false();
        });

        it('adds class if .modal-body changes, causing overflow', async () => {
          const modal = mountComponent({
            props: { size: 'full' },
            slots: {
              body: { template: '<div id="div" style="height: 10px;"></div>' }
            },
            attachTo: document.body
          });
          await nextTick();
          modal.classes('has-scroll').should.be.false();
          modal.get('#div').element.setAttribute('style', 'height: 10000px;');
          await wait();
          modal.classes('has-scroll').should.be.true();
        });
      });
    });
  });
});
