# JUZARA Health — Public Patient Accounts

## Apa yang baru
- Masyarakat dapat membuat akun pasien sendiri melalui halaman Registrasi.
- Login pasien memakai email + password.
- Login dokter terpisah; pendaftaran publik tidak dapat membuat akun dokter.
- Mode cloud menggunakan Supabase Auth + tabel profil dengan Row Level Security.
- Jika konfigurasi Supabase belum diisi, situs berjalan dalam mode demo lokal. Mode demo tidak membagikan akun antarperangkat.

## A. Siapkan database dan autentikasi publik
1. Buat project di https://supabase.com/.
2. Buka Project Settings → API. Salin Project URL dan `anon`/publishable key.
3. Isi kedua nilai tersebut di `config.js`. Jangan pernah menaruh `service_role` key di website.
4. Buka SQL Editor di Supabase, jalankan seluruh isi `supabase-setup.sql`.
5. Buka Authentication → URL Configuration. Set Site URL ke domain Vercel, misalnya `https://juzara-health-fresh.vercel.app`. Tambahkan domain itu ke Redirect URLs.
6. Untuk uji awal, Authentication → Providers → Email aktif. Atur verifikasi email sesuai kebijakan layanan. Disarankan verifikasi email tetap aktif.

## B. Deploy ke GitHub dan Vercel
1. Buat repository GitHub baru.
2. Upload seluruh isi folder ini, termasuk `config.js` dan `supabase-setup.sql`.
3. Di Vercel pilih Add New → Project → import repository.
4. Framework Preset: Other; Root Directory: `./`; Build Command: kosong; Output Directory: `./`; Install Command: kosong.
5. Deploy. Jika mengubah URL domain, sesuaikan Site URL dan Redirect URLs di Supabase.

## C. Membuat akun dokter terverifikasi
Jangan sediakan registrasi dokter publik. Admin membuat akun dokter melalui Supabase Dashboard → Authentication → Users → Add user (atau undangan email). Setelah user dibuat, ubah role profilnya melalui SQL Editor memakai UUID user yang benar:
`update public.profiles set role = 'doctor', name = 'dr. Nama Dokter' where id = 'UUID_USER_DOKTER';`
Akun dokter harus hanya diberikan setelah verifikasi identitas dan kewenangan. Jangan membagikan password bersama; dokter sebaiknya membuat password sendiri melalui undangan/reset email.

## D. Batasan saat ini
Integrasi cloud dalam paket ini mengaktifkan registrasi, login, verifikasi email, reset password, dan profil akun. Modul antrean/chat/lab masih memakai penyimpanan lokal browser pada prototipe ini dan belum menjadi rekam medis lintas pengguna. Jangan memasukkan data pasien nyata sebelum backend, otorisasi per pasien/dokter, audit log, backup, enkripsi, serta kepatuhan perlindungan data kesehatan selesai ditinjau.
