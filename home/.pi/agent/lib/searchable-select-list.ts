/**
 * SearchableSelectList — a SelectList with a search input above it.
 *
 * pi-tui removed `SelectList.searchable`; filtering is now composed manually
 * (the same pattern pi's own model/theme selectors use): route navigation
 * keys to the SelectList and everything else to an Input whose value drives
 * `setFilter()`.
 */

import {
  Container,
  getKeybindings,
  Input,
  SelectList,
  type Component,
  type SelectItem,
  type SelectListTheme,
} from '@earendil-works/pi-tui';

export class SearchableSelectList implements Component {
  private container = new Container();
  private searchInput = new Input();
  readonly selectList: SelectList;

  onSelect?: (item: SelectItem) => void;
  onCancel?: () => void;

  constructor(items: SelectItem[], maxVisible: number, theme: SelectListTheme) {
    this.selectList = new SelectList(items, maxVisible, theme);
    this.selectList.onSelect = (item) => this.onSelect?.(item);
    this.selectList.onCancel = () => this.onCancel?.();
    this.container.addChild(this.searchInput);
    this.container.addChild(this.selectList);
  }

  render(width: number): string[] {
    return this.container.render(width);
  }

  invalidate(): void {
    this.container.invalidate();
  }

  handleInput(keyData: string): void {
    const kb = getKeybindings();
    if (
      kb.matches(keyData, 'tui.select.up') ||
      kb.matches(keyData, 'tui.select.down') ||
      kb.matches(keyData, 'tui.select.confirm') ||
      kb.matches(keyData, 'tui.select.cancel')
    ) {
      this.selectList.handleInput(keyData);
    } else {
      this.searchInput.handleInput(keyData);
      this.selectList.setFilter(this.searchInput.getValue());
    }
  }
}
