const SVG = 'http://www.w3.org/2000/svg'
const DROP = 'M22 50C22 50 38 33 38 19.5A16 16 0 0 0 6 19.5C6 33 22 50 22 50Z'
const CROSS = 'M19.5 12.5h5v4.5h4.5v5h-4.5v4.5h-5v-4.5H15v-5h4.5z'

function path(className: string, d: string) {
  const element = document.createElementNS(SVG, 'path')
  element.setAttribute('class', className)
  element.setAttribute('d', d)
  return element
}

/**
 * Pins are pointer shortcuts only, so they are hidden from assistive technology and not focusable:
 * the result list is the accessible way to reach the same pharmacies.
 * MapLibre writes `transform` and `opacity` on the root, so all visual states live on its children.
 */
export function createPharmacyPin(onClick: () => void): HTMLElement {
  const root = document.createElement('div')
  root.className = 'pmap-pin'
  root.setAttribute('aria-hidden', 'true')
  root.addEventListener('click', onClick)

  const svg = document.createElementNS(SVG, 'svg')
  svg.setAttribute('class', 'pmap-pin__shape')
  svg.setAttribute('viewBox', '0 0 44 52')
  svg.append(path('pmap-pin__drop', DROP), path('pmap-pin__cross', CROSS))

  const tag = document.createElement('span')
  tag.className = 'pmap-pin__tag'
  tag.textContent = 'Nearest'

  root.append(svg, tag)
  return root
}

export function updatePharmacyPin(root: HTMLElement, name: string, nearest: boolean, selected: boolean) {
  root.title = name
  root.classList.toggle('pmap-pin--nearest', nearest)
  root.classList.toggle('pmap-pin--selected', selected)
}

export function createUserPin(): HTMLElement {
  const root = document.createElement('div')
  root.className = 'pmap-user'
  root.setAttribute('aria-hidden', 'true')
  return root
}
