"use client";

import { useState, type CSSProperties } from "react";
import {
  Bell,
  BookOpen,
  CalendarDays,
  Check,
  ChevronRight,
  CircleUserRound,
  Flame,
  GraduationCap,
  HandHeart,
  Home,
  Library,
  Menu,
  MessageCircle,
  MoreHorizontal,
  Play,
  Search,
  ShoppingBag,
  Sparkles,
  Trophy,
  Users,
  X,
  Zap,
} from "lucide-react";
import styles from "./page.module.css";

const navigation = [
  { label: "Home", icon: Home },
  { label: "Tasks", icon: Zap, badge: "3" },
  { label: "Academics", icon: GraduationCap },
  { label: "Events", icon: CalendarDays },
  { label: "Prayer wall", icon: HandHeart },
  { label: "Messages", icon: MessageCircle, badge: "5" },
];

const explore = [
  { label: "Resources", icon: Library },
  { label: "Leaderboard", icon: Trophy },
  { label: "Coin store", icon: ShoppingBag },
];

const initialTasks = [
  {
    id: 1,
    title: "Morning devotion",
    meta: "Read John 15:1–11",
    reward: 20,
    complete: true,
    icon: BookOpen,
  },
  {
    id: 2,
    title: "Prayer focus",
    meta: "Pray for the campus community",
    reward: 15,
    complete: false,
    icon: HandHeart,
  },
  {
    id: 3,
    title: "Weekly reflection",
    meta: "Share one lesson from Sunday",
    reward: 30,
    complete: false,
    icon: Sparkles,
  },
];

type Task = (typeof initialTasks)[number];

function BrandMark() {
  return (
    <div className={styles.brandMark} aria-hidden="true">
      <span className={styles.crossVertical} />
      <span className={styles.crossHorizontal} />
      <span className={styles.bookLeft} />
      <span className={styles.bookRight} />
    </div>
  );
}

function ProgressRing({ value }: { value: number }) {
  return (
    <div
      className={styles.progressRing}
      style={{ "--progress": `${value * 3.6}deg` } as CSSProperties}
      aria-label={`${value}% level progress`}
    >
      <div className={styles.progressRingInner}>
        <strong>{value}%</strong>
        <span>Level 8</span>
      </div>
    </div>
  );
}

export default function HomePage() {
  const [active, setActive] = useState("Home");
  const [tasks, setTasks] = useState<Task[]>(initialTasks);
  const [menuOpen, setMenuOpen] = useState(false);

  const completedTasks = tasks.filter((task) => task.complete).length;
  const taskProgress = Math.round((completedTasks / tasks.length) * 100);

  const toggleTask = (id: number) => {
    setTasks((current) =>
      current.map((task) =>
        task.id === id ? { ...task, complete: !task.complete } : task,
      ),
    );
  };

  const choosePage = (label: string) => {
    setActive(label);
    setMenuOpen(false);
  };

  return (
    <main className={styles.appShell}>
      <aside
        className={`${styles.sidebar} ${menuOpen ? styles.sidebarOpen : ""}`}
      >
        <div className={styles.brand}>
          <BrandMark />
          <div>
            <strong>ACCF Ikole</strong>
            <span>One family in Christ</span>
          </div>
          <button
            className={styles.closeMenu}
            aria-label="Close menu"
            onClick={() => setMenuOpen(false)}
          >
            <X size={20} />
          </button>
        </div>

        <nav className={styles.navigation} aria-label="Primary navigation">
          <span className={styles.navLabel}>Main menu</span>
          {navigation.map((item) => {
            const Icon = item.icon;
            const selected = active === item.label;
            return (
              <button
                key={item.label}
                className={`${styles.navItem} ${selected ? styles.navItemActive : ""}`}
                onClick={() => choosePage(item.label)}
                aria-current={selected ? "page" : undefined}
              >
                <Icon size={19} strokeWidth={selected ? 2.4 : 1.9} />
                <span>{item.label}</span>
                {item.badge && <small>{item.badge}</small>}
              </button>
            );
          })}

          <span className={styles.navLabel}>Explore</span>
          {explore.map((item) => {
            const Icon = item.icon;
            const selected = active === item.label;
            return (
              <button
                key={item.label}
                className={`${styles.navItem} ${selected ? styles.navItemActive : ""}`}
                onClick={() => choosePage(item.label)}
              >
                <Icon size={19} strokeWidth={selected ? 2.4 : 1.9} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className={styles.sidebarInvite}>
          <div className={styles.inviteIcon}>
            <Users size={18} />
          </div>
          <strong>Invite a fellowship member</strong>
          <p>Grow our digital community together.</p>
          <button>Share invite</button>
        </div>

        <button
          className={styles.userMini}
          onClick={() => choosePage("Profile")}
        >
          <span className={styles.avatar}>OI</span>
          <span>
            <strong>Ifeoluwa</strong>
            <small>Member · Level 8</small>
          </span>
          <MoreHorizontal size={18} />
        </button>
      </aside>

      {menuOpen && (
        <button
          className={styles.backdrop}
          aria-label="Close navigation"
          onClick={() => setMenuOpen(false)}
        />
      )}

      <section className={styles.content}>
        <header className={styles.topbar}>
          <div className={styles.mobileBrand}>
            <button
              className={styles.iconButton}
              aria-label="Open menu"
              onClick={() => setMenuOpen(true)}
            >
              <Menu size={20} />
            </button>
            <BrandMark />
            <strong>ACCF</strong>
          </div>
          <label className={styles.searchBox}>
            <Search size={18} />
            <input
              aria-label="Search"
              placeholder="Search resources, events, people..."
            />
            <kbd>⌘ K</kbd>
          </label>
          <div className={styles.topbarActions}>
            <span className={styles.date}>Monday, 21 September</span>
            <button className={styles.iconButton} aria-label="Notifications">
              <Bell size={19} />
              <span className={styles.notificationDot} />
            </button>
            <button className={styles.profileButton}>
              <span className={styles.avatar}>OI</span>
              <ChevronRight size={16} />
            </button>
          </div>
        </header>

        <div className={styles.pageContent}>
          <div className={styles.welcomeRow}>
            <div>
              <span className={styles.eyebrow}>Member home</span>
              <h1>Good morning, Ifeoluwa.</h1>
              <p>Keep growing in faith, learning and fellowship today.</p>
            </div>
            <div className={styles.quickStats}>
              <div>
                <span className={styles.statIconWarm}>
                  <Flame size={18} fill="currentColor" />
                </span>
                <p>
                  <strong>12 days</strong>
                  <small>Current streak</small>
                </p>
              </div>
              <div>
                <span className={styles.statIconGold}>C</span>
                <p>
                  <strong>2,480</strong>
                  <small>Coins earned</small>
                </p>
              </div>
              <div>
                <span className={styles.statIconBlue}>
                  <Trophy size={17} />
                </span>
                <p>
                  <strong>#14</strong>
                  <small>Leaderboard</small>
                </p>
              </div>
            </div>
          </div>

          <div className={styles.dashboardGrid}>
            <section className={styles.mainColumn}>
              <article className={styles.devotionCard}>
                <div className={styles.devotionGlow} />
                <div className={styles.devotionTopline}>
                  <span>
                    <Sparkles size={14} /> Scripture for today
                  </span>
                  <small>4 min read</small>
                </div>
                <blockquote>
                  “Abide in me, and I in you. As the branch cannot bear fruit by
                  itself, unless it abides in the vine, neither can you, unless
                  you abide in me.”
                </blockquote>
                <p>John 15:4</p>
                <div className={styles.devotionFooter}>
                  <button className={styles.lightButton}>
                    <Play size={15} fill="currentColor" /> Read &amp; reflect
                  </button>
                  <span>Theme: Staying connected to Christ</span>
                </div>
              </article>

              <article className={`${styles.card} ${styles.tasksCard}`}>
                <div className={styles.cardHeader}>
                  <div>
                    <span className={styles.eyebrow}>Daily rhythm</span>
                    <h2>Today&apos;s tasks</h2>
                  </div>
                  <span className={styles.progressText}>
                    {completedTasks}/{tasks.length} complete
                  </span>
                </div>
                <div className={styles.progressTrack}>
                  <span style={{ width: `${taskProgress}%` }} />
                </div>
                <div className={styles.taskList}>
                  {tasks.map((task) => {
                    const Icon = task.icon;
                    return (
                      <button
                        key={task.id}
                        className={`${styles.taskItem} ${task.complete ? styles.taskComplete : ""}`}
                        onClick={() => toggleTask(task.id)}
                      >
                        <span className={styles.taskCheck}>
                          {task.complete && <Check size={15} strokeWidth={3} />}
                        </span>
                        <span className={styles.taskIcon}>
                          <Icon size={18} />
                        </span>
                        <span className={styles.taskCopy}>
                          <strong>{task.title}</strong>
                          <small>{task.meta}</small>
                        </span>
                        <span className={styles.coinReward}>
                          +{task.reward} C
                        </span>
                      </button>
                    );
                  })}
                </div>
                <button className={styles.textButton}>
                  View all tasks <ChevronRight size={15} />
                </button>
              </article>

              <article className={styles.challengeCard}>
                <div className={styles.challengeIcon}>
                  <Zap size={21} fill="currentColor" />
                </div>
                <div className={styles.challengeCopy}>
                  <span className={styles.eyebrow}>Weekly challenge</span>
                  <h2>Encourage three people this week</h2>
                  <p>
                    Send a thoughtful message, pray with them, or offer
                    practical help.
                  </p>
                  <div className={styles.challengeProgress}>
                    <div>
                      <span style={{ width: "66%" }} />
                    </div>
                    <small>2 of 3 complete</small>
                  </div>
                </div>
                <div className={styles.challengeReward}>
                  <span>Reward</span>
                  <strong>+100 C</strong>
                  <button>Continue</button>
                </div>
              </article>
            </section>

            <aside className={styles.rightColumn}>
              <article className={`${styles.card} ${styles.growthCard}`}>
                <div className={styles.cardHeader}>
                  <div>
                    <span className={styles.eyebrow}>Your journey</span>
                    <h2>Growth progress</h2>
                  </div>
                  <button
                    className={styles.moreButton}
                    aria-label="More options"
                  >
                    <MoreHorizontal size={19} />
                  </button>
                </div>
                <div className={styles.growthBody}>
                  <ProgressRing value={72} />
                  <div className={styles.growthStats}>
                    <div>
                      <span>XP earned</span>
                      <strong>3,640</strong>
                    </div>
                    <div>
                      <span>Next level</span>
                      <strong>360 XP</strong>
                    </div>
                  </div>
                </div>
                <div className={styles.milestone}>
                  <span>
                    <Trophy size={18} />
                  </span>
                  <div>
                    <strong>Next milestone</strong>
                    <small>Complete 5 more weekly tasks</small>
                  </div>
                </div>
              </article>

              <article className={`${styles.card} ${styles.eventCard}`}>
                <div className={styles.cardHeader}>
                  <div>
                    <span className={styles.eyebrow}>Coming up</span>
                    <h2>Next fellowship event</h2>
                  </div>
                  <button className={styles.textButton}>All events</button>
                </div>
                <div className={styles.eventVisual}>
                  <div className={styles.eventPattern} />
                  <span>ACCF</span>
                  <strong>Word &amp; Worship</strong>
                </div>
                <div className={styles.eventDetails}>
                  <div className={styles.dateTile}>
                    <strong>24</strong>
                    <span>SEP</span>
                  </div>
                  <div>
                    <strong>Word &amp; Worship Night</strong>
                    <span>Wednesday · 5:00 PM</span>
                    <small>ACCF Secretariat, Ikole</small>
                  </div>
                </div>
                <button className={styles.primaryButton}>
                  View event details
                </button>
              </article>

              <article className={`${styles.card} ${styles.academicsCard}`}>
                <div className={styles.academicIcon}>
                  <GraduationCap size={22} />
                </div>
                <div>
                  <span className={styles.eyebrow}>Academics</span>
                  <h2>Your study space</h2>
                  <p>
                    Past questions, materials and AI-assisted study tools in one
                    place.
                  </p>
                </div>
                <button aria-label="Open academics">
                  <ChevronRight size={18} />
                </button>
              </article>
            </aside>
          </div>
        </div>

        <nav className={styles.mobileNav} aria-label="Mobile navigation">
          {navigation.slice(0, 4).map((item) => {
            const Icon = item.icon;
            const selected = active === item.label;
            return (
              <button
                key={item.label}
                className={selected ? styles.mobileActive : ""}
                onClick={() => choosePage(item.label)}
              >
                <Icon size={20} />
                <span>{item.label}</span>
              </button>
            );
          })}
          <button onClick={() => setMenuOpen(true)}>
            <CircleUserRound size={20} />
            <span>More</span>
          </button>
        </nav>
      </section>
    </main>
  );
}
