'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Activity,
  Download,
  GitBranch,
  Package,
  Clock,
  CheckCircle,
  XCircle,
  AlertCircle,
  PlayCircle,
  Plus
} from 'lucide-react'
import Link from 'next/link'

export default function Dashboard() {
  const [currentTask, setCurrentTask] = useState<any>(null)
  const [statistics, setStatistics] = useState({
    totalTasks: 0,
    successRate: 0,
    avgDuration: 0,
    todayBuilds: 0
  })

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Package className="h-6 w-6" />
              <h1 className="text-2xl font-bold">Flutter Unity Build Tool</h1>
            </div>
            <nav className="flex items-center space-x-4">
              <Link href="/tasks/new">
                <Button>
                  <Plus className="mr-2 h-4 w-4" />
                  新建任务
                </Button>
              </Link>
              <Link href="/settings">
                <Button variant="outline">设置</Button>
              </Link>
            </nav>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {/* 统计卡片 */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">今日构建</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{statistics.todayBuilds}</div>
              <p className="text-xs text-muted-foreground">较昨日 +12%</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">成功率</CardTitle>
              <CheckCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{statistics.successRate}%</div>
              <p className="text-xs text-muted-foreground">最近30天</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">平均耗时</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{statistics.avgDuration}分钟</div>
              <p className="text-xs text-muted-foreground">包含所有阶段</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">总任务数</CardTitle>
              <Package className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{statistics.totalTasks}</div>
              <p className="text-xs text-muted-foreground">累计任务</p>
            </CardContent>
          </Card>
        </div>

        {/* 当前任务状态 */}
        {currentTask && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <PlayCircle className="h-5 w-5" />
                当前任务进行中
              </CardTitle>
              <CardDescription>
                任务 ID: {currentTask.id} | 触发人: {currentTask.initiator}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <Badge variant="default">Unity: {currentTask.unityBranch}</Badge>
                    <Badge variant="outline">Flutter: {currentTask.flutterBranch}</Badge>
                  </div>
                  <span className="text-sm text-muted-foreground">
                    已运行: {currentTask.duration}
                  </span>
                </div>
                <Progress value={currentTask.progress} className="w-full" />
                <div className="text-sm text-muted-foreground">
                  当前阶段: {currentTask.currentStage}
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* 任务历史和产物 */}
        <Tabs defaultValue="recent" className="space-y-4">
          <TabsList>
            <TabsTrigger value="recent">最近任务</TabsTrigger>
            <TabsTrigger value="artifacts">构建产物</TabsTrigger>
            <TabsTrigger value="logs">任务日志</TabsTrigger>
          </TabsList>

          <TabsContent value="recent" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>最近任务历史</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {/* 示例任务项 */}
                  <div className="flex items-center justify-between border-b pb-4">
                    <div className="flex items-center gap-4">
                      <CheckCircle className="h-5 w-5 text-green-500" />
                      <div>
                        <p className="font-medium">任务 #12345</p>
                        <p className="text-sm text-muted-foreground">
                          Unity: main | Flutter: develop
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <span className="text-sm text-muted-foreground">耗时: 25分钟</span>
                      <Button size="sm" variant="outline">
                        <Download className="h-4 w-4 mr-2" />
                        下载
                      </Button>
                    </div>
                  </div>

                  <div className="flex items-center justify-between border-b pb-4">
                    <div className="flex items-center gap-4">
                      <XCircle className="h-5 w-5 text-red-500" />
                      <div>
                        <p className="font-medium">任务 #12344</p>
                        <p className="text-sm text-muted-foreground">
                          Unity: feature/ui | Flutter: main
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <span className="text-sm text-muted-foreground">失败: Unity导出</span>
                      <Button size="sm" variant="outline">查看日志</Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="artifacts">
            <Card>
              <CardHeader>
                <CardTitle>构建产物</CardTitle>
                <CardDescription>所有成功构建的APK文件</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="text-center py-8 text-muted-foreground">
                    产物列表将在后端连接后显示
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="logs">
            <Card>
              <CardHeader>
                <CardTitle>任务日志</CardTitle>
                <CardDescription>查看详细的构建日志</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="text-center py-8 text-muted-foreground">
                    日志内容将在后端连接后显示
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  )
}