// The composer remains in ConversationRoot so switching out of the blank-draft
// phase does not remount its textarea.

import type { ReactNode, RefObject } from 'react'
import {
  IconChevronDownOutline14, IconFolderClose16, IconFolderOpen16,
} from '@deepseek-ai/dsh-client-ui-primitives'
import { workspaceTitleOf } from '@deepseek-ai/dsh-util-workspace-path'
import type { ConversationSlotProps } from '../contract/slots.ts'
import css from './HeroShell.module.css'

/** The owner's locale seat type, passed to hero chrome as a plain prop. */
type HeroTranslate = ConversationSlotProps['t']

/**
 * Basename label for the workspace chip (the shared derivation);
 * separator-only paths echo the raw cwd.
 * @param cwd - workspace directory path (non-empty).
 * @returns chip label.
 */
export function workspaceLabel(cwd: string): string {
  const base = workspaceTitleOf(cwd)
  return base !== '' ? base : cwd
}

/**
 * The workspace chip (folder + label + chevron), always interactive: before
 * the first message the workspace stays switchable — picking another one
 * moves the New Session flow to that workspace's blank session. Without a
 * label the chip renders its placeholder state: closed folder + the
 * "Choose workspace" call to action.
 * @param props.label - chip label (see {@link workspaceLabel}); omitted → placeholder.
 * @param props.menuOpen - menu expansion echo.
 * @param props.onClick - menu toggle.
 * @returns the chip button element.
 */
export function WorkspaceChip({ buttonRef, label, menuOpen = false, onClick, t }: {
  buttonRef?: RefObject<HTMLButtonElement>
  label?: string | undefined
  menuOpen?: boolean
  onClick?: () => void
  t: HeroTranslate
}) {
  return (
    <button
      ref={buttonRef}
      type="button"
      className={css.workspace}
      aria-label={t('hero.chooseWorkspace')}
      aria-haspopup="menu"
      aria-expanded={menuOpen}
      onClick={onClick}
    >
      {label === undefined
        ? <IconFolderClose16 className={css.folder} size={16} />
        : <IconFolderOpen16 className={css.folder} size={16} />}
      <span className={css.workspaceLabel}>{label ?? t('hero.chooseWorkspace')}</span>
      <IconChevronDownOutline14 className={css.chevron} size={12} />
    </button>
  )
}

/** Hero chrome props. The workspace row rides the InputBar accessory hole, not here. */
export interface HeroShellProps {
  /** The owner's locale seat, passed down as a plain prop. */
  t: HeroTranslate
  /** Authorized renderer for the hero brand-mark slot. */
  renderSlot: ConversationSlotProps['renderSlot']
  /** Overlay content after the stack (modals). */
  children?: ReactNode
}


/**
 * MaixCAM 首屏标记（默认 34px）。这是本项目对上游的第二处品牌改动：
 * 首屏标题前原本是一只动画鲸鱼，换成本应用的摄像头模组标记。
 * 用 `currentColor` 绘制，自动跟随明暗主题。
 * @param props.size - 请求的边长（像素）。
 * @returns 标记 svg 元素。
 */
function MaixCamHeroMark({ size }: { size: number }) {
  return (
    <svg
      className={css.fish}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      focusable="false"
    >
      <rect
        x="2.6" y="2.6" width="18.8" height="18.8" rx="5.4"
        stroke="currentColor" strokeWidth="1.5" opacity="0.5"
      />
      <circle cx="12" cy="12.4" r="5.1" stroke="currentColor" strokeWidth="1.5" />
      <circle cx="12" cy="12.4" r="2" fill="currentColor" />
      <circle cx="16.9" cy="7.2" r="1.05" fill="currentColor" opacity="0.7" />
    </svg>
  )
}

/**
 * Render the hero chrome (headline only; no composer, no workspace row).
 * @param props - see {@link HeroShellProps}.
 * @returns the centered hero element tree.
 */
export function HeroShell({ t, renderSlot, children }: HeroShellProps) {
  return (
    <div className={css.root}>
      <div className={css.stack}>
        <div className={css.headline}>
          {/* figma 34:10412: fish 34×25 leading the headline, gap 10. */}
          <span className={css.fishHitbox}>
            {renderSlot('conversation.hero.brand.mark', { size: 34, className: css.fish }, {
              fallback: <MaixCamHeroMark size={34} />,
            })}
          </span>
          <span className={css.titleGroup}>
            {/* Own element: keeps the headline text addressable apart from the badge. */}
            <span>{t('hero.headline')}</span>
            <span className={css.previewBadge}>{t('hero.preview')}</span>
          </span>
        </div>
        <div className={css.body}>
          {/* The composer remains mounted outside this component. */}
        </div>
      </div>
      {children}
    </div>
  )
}
