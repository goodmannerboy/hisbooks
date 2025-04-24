import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { motion } from "framer-motion";

export default function HisbooksHomepage() {
  return (
    <main className="p-4 md:p-10 max-w-6xl mx-auto space-y-12">
      <motion.header
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-center space-y-4"
      >
        <h1 className="text-5xl font-bold text-green-800">HISBOOKS</h1>
        <p className="text-gray-700 text-lg">
          Premium English Study Materials by HIS Language Academy
        </p>
      </motion.header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <Card className="rounded-2xl shadow-md">
          <CardContent className="p-6">
            <h2 className="text-xl font-semibold text-green-700">About HISBOOKS</h2>
            <p className="mt-3 text-gray-700 text-sm">
              HISBOOKS is the official publishing brand of HIS Language Academy in Pohang.
              We develop English learning content for elementary to high school students,
              optimized for Korean CSAT and school curricula.
            </p>
          </CardContent>
        </Card>

        <Card className="rounded-2xl shadow-md">
          <CardContent className="p-6">
            <h2 className="text-xl font-semibold text-green-700">Our Products</h2>
            <ul className="mt-3 text-gray-700 text-sm list-disc list-inside space-y-1">
              <li>Grammar Master: 중등 문법 완성 시리즈</li>
              <li>Reading Drill 7-Day: 끊어읽기 훈련 교재</li>
              <li>AI 오답노트 시스템: 진단 → 약점 분석 → 맞춤 과제</li>
            </ul>
          </CardContent>
        </Card>

        <Card className="rounded-2xl shadow-md">
          <CardContent className="p-6">
            <h2 className="text-xl font-semibold text-green-700">Sample & Inquiries</h2>
            <p className="mt-3 text-sm text-gray-700">
              Sample PDF and workbook excerpts available upon request.
            </p>
            <form className="space-y-3 mt-4">
              <Input placeholder="Your name" />
              <Input placeholder="Your email" type="email" />
              <Textarea placeholder="Your message..." rows={3} />
              <Button className="bg-green-700 text-white w-full">Send Request</Button>
            </form>
          </CardContent>
        </Card>
      </section>

      <section className="bg-green-50 rounded-2xl p-6 text-center space-y-2">
        <h2 className="text-xl font-bold text-green-700">📦 Download Free Sample</h2>
        <p className="text-gray-600 text-sm">
          Get your hands on a preview of our workbooks before you buy.
        </p>
        <Button className="bg-green-700 text-white">Download PDF Sample</Button>
      </section>

      <motion.footer
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        className="text-center text-sm text-gray-500 pt-10"
      >
        &copy; 2025 HISBOOKS. All rights reserved. Designed by HIS LANGUAGE.
      </motion.footer>
    </main>
  );
}
