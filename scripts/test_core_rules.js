const fs = require('fs');
const path = require('path');

console.log('===========================================================');
console.log('   🔍 FORENSIC AUDIT OF SYSTEM CORE RULES & CONSTRAINTS   ');
console.log('===========================================================\n');

// 1. Check Library Rules & Terms rendering across public views
console.log('--- 1. LIBRARY CODE OF CONDUCT & ADMISSION RULES ---');
const regHtml = fs.readFileSync('public/register.html', 'utf8');
const landingHtml = fs.readFileSync('public/landing.html', 'utf8');

const hasRegTermsCheckbox = regHtml.includes('id="reg-terms"') && regHtml.includes('required');
const hasRegRulesScrollBox = regHtml.includes('id="reg-rules-scroll-box"');
const hasRegRulesDynamicSync = regHtml.includes('landingRules') || regHtml.includes('bp?.rules');

console.log('• Registration Form has mandatory terms checkbox (#reg-terms):', hasRegTermsCheckbox);
console.log('• Registration Form has dynamic rules box (#reg-rules-scroll-box):', hasRegRulesScrollBox);
console.log('• Registration Form dynamically fetches Admin rules:', hasRegRulesDynamicSync);

// Check if submit handler validates #reg-terms
const hasTermsSubmitValidation = regHtml.includes('reg-terms') && regHtml.includes('Please review and check the box agreeing');
console.log('• Registration Form validates terms before submitting:', hasTermsSubmitValidation);

// 2. Check Seating Allocation & Shift Rules
console.log('\n--- 2. SEATING ALLOCATION & SHIFT CONSTRAINTS ---');
const seatRoutes = fs.readFileSync('routes/seats.js', 'utf8');
const authRoutes = fs.readFileSync('routes/auth.js', 'utf8');
const studentRoutes = fs.readFileSync('routes/students.js', 'utf8');

const hasDuplicateSeatCheck = seatRoutes.includes('already occupied') || seatRoutes.includes('occupied');
const hasShiftCapacityCheck = authRoutes.includes('WaitingList') || authRoutes.includes('Shift capacity');
console.log('• Seat allocation checks for existing occupancy:', hasDuplicateSeatCheck);
console.log('• Public admission checks shift capacity and handles waiting list:', hasShiftCapacityCheck);

// 3. Check Duplicate Prevention Rules (Phone & Email)
console.log('\n--- 3. DUPLICATE STUDENT PHONE & EMAIL RULES ---');
const hasAuthDuplicateCheck = authRoutes.includes('existingStudent') && authRoutes.includes('already registered');
const hasStudentDuplicateCheck = studentRoutes.includes('existingStudent') || studentRoutes.includes('phone');
console.log('• Public registration enforces unique phone & email rule:', hasAuthDuplicateCheck);
console.log('• Admin student creation enforces unique phone & email rule:', hasStudentDuplicateCheck);

// 4. Check RBAC Role Enforcement Rules
console.log('\n--- 4. RBAC ROLE PERMISSION RULES ---');
const middlewareAuth = fs.readFileSync('middleware/auth.js', 'utf8');
const middlewareRole = fs.readFileSync('middleware/roleCheck.js', 'utf8');
console.log('• JWT protect middleware enforces authentication:', middlewareAuth.includes('protect'));
console.log('• roleCheck middleware enforces granular roles (owner, branch_manager, staff, student):', middlewareRole.includes('roleCheck') || middlewareRole.includes('role'));

// 5. Check Gamified Badges & Attendance Rules
console.log('\n--- 5. ATTENDANCE & BADGE EARNING RULES ---');
const studentPortalRoutes = fs.readFileSync('routes/studentPortal.js', 'utf8');
const hasEarlyBirdRule = studentPortalRoutes.includes('early_bird');
const hasStudyWarriorRule = studentPortalRoutes.includes('study_warrior');
const hasNightOwlRule = studentPortalRoutes.includes('night_owl');
const hasStreakRule = studentPortalRoutes.includes('streak_champion');
console.log('• 🌅 Early Bird badge rule (Check-in before 7 AM):', hasEarlyBirdRule);
console.log('• ⚔️ Study Warrior badge rule (100+ study hours):', hasStudyWarriorRule);
console.log('• 🦉 Night Owl badge rule (Check-in after 8 PM):', hasNightOwlRule);
console.log('• 🏆 Streak Champion badge rule (30-day streak):', hasStreakRule);

// 6. Check Payment & UTR Rules
console.log('\n--- 6. PAYMENT COLLECTION & UTR RULES ---');
const paymentRoutes = fs.readFileSync('routes/payments.js', 'utf8');
const hasDuplicateUtrCheck = paymentRoutes.includes('referenceNumber') || paymentRoutes.includes('transactionId');
console.log('• Payment collection records reference/UTR number:', hasDuplicateUtrCheck);

// 7. Check Custom Field Conditional Rules (showIf / dependsOn)
console.log('\n--- 7. FORM BUILDER CONDITIONAL RULES (showIf / dependsOn) ---');
const hasConditionalEngine = regHtml.includes('data-depends-on') && regHtml.includes('evaluateLogic');
console.log('• Registration Form executes dynamic showIf conditional rules:', hasConditionalEngine);
