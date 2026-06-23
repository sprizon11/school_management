import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(private prisma: PrismaService) {}

  async listForTeacher(teacherId: string, schoolId: string) {
    const classIds = await this.teacherClassIds(teacherId);
    if (classIds.length === 0) return [];

    const students = await this.prisma.student.findMany({
      where: { classId: { in: classIds } },
      include: {
        class: true,
        parent: { include: { user: true } },
        chatConversations: {
          where: { teacherId },
          take: 1,
        },
      },
      orderBy: { fullName: 'asc' },
    });

    const rows = await Promise.all(
      students.map(async (student) => {
        let conversation = student.chatConversations[0];
        if (!conversation) {
          conversation = await this.prisma.chatConversation.create({
            data: {
              schoolId,
              teacherId,
              studentId: student.id,
            },
          });
        }

        const unread = await this.prisma.chatMessage.count({
          where: {
            conversationId: conversation.id,
            readAt: null,
            senderUser: { role: UserRole.PARENT },
          },
        });

        const parentName =
          student.parent?.user.fullName ||
          student.fatherName ||
          student.motherName ||
          'Parent';

        return {
          id: conversation.id,
          studentId: student.id,
          studentName: student.fullName,
          classLabel: `${student.class.grade}${student.class.section}`,
          parentName,
          lastMessage: conversation.lastMessage,
          lastMessageAt: conversation.lastMessageAt,
          unread,
        };
      }),
    );

    rows.sort((a, b) => {
      const at = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0;
      const bt = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0;
      return bt - at;
    });

    return rows;
  }

  async listForParent(userId: string, schoolId: string) {
    const parent = await this.prisma.parent.findUnique({
      where: { userId },
      include: {
        student: {
          include: {
            class: { include: { classTeacher: { include: { user: true } } } },
          },
        },
      },
    });
    if (!parent) throw new NotFoundException('Parent profile not found');

    const teacher = parent.student.class.classTeacher;
    if (!teacher) return [];

    let conversation = await this.prisma.chatConversation.findUnique({
      where: {
        teacherId_studentId: {
          teacherId: teacher.id,
          studentId: parent.studentId,
        },
      },
    });
    if (!conversation) {
      conversation = await this.prisma.chatConversation.create({
        data: {
          schoolId,
          teacherId: teacher.id,
          studentId: parent.studentId,
        },
      });
    }

    const unread = await this.prisma.chatMessage.count({
      where: {
        conversationId: conversation.id,
        readAt: null,
        senderUser: { role: UserRole.TEACHER },
      },
    });

    return [
      {
        id: conversation.id,
        teacherName: teacher.user.fullName,
        studentName: parent.student.fullName,
        classLabel: `${parent.student.class.grade}${parent.student.class.section}`,
        subject: teacher.subjects[0] ?? teacher.department,
        lastMessage: conversation.lastMessage,
        lastMessageAt: conversation.lastMessageAt,
        unread,
      },
    ];
  }

  async messages(conversationId: string, userId: string, role: UserRole) {
    await this.assertAccess(conversationId, userId, role);
    const items = await this.prisma.chatMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
      take: 200,
      include: {
        senderUser: { select: { id: true, role: true, fullName: true } },
      },
    });

    await this.prisma.chatMessage.updateMany({
      where: {
        conversationId,
        readAt: null,
        senderUserId: { not: userId },
      },
      data: { readAt: new Date() },
    });

    return items.map((m) => ({
      id: m.id,
      body: m.body,
      createdAt: m.createdAt,
      readAt: m.readAt,
      isMine: m.senderUserId === userId,
      senderName: m.senderUser.fullName,
      senderRole: m.senderUser.role,
    }));
  }

  async send(
    conversationId: string,
    userId: string,
    role: UserRole,
    body: string,
  ) {
    const text = body.trim();
    if (!text) throw new ForbiddenException('Message cannot be empty');

    await this.assertAccess(conversationId, userId, role);

    const message = await this.prisma.chatMessage.create({
      data: {
        conversationId,
        senderUserId: userId,
        body: text,
      },
    });

    await this.prisma.chatConversation.update({
      where: { id: conversationId },
      data: {
        lastMessage: text,
        lastMessageAt: message.createdAt,
      },
    });

    return {
      id: message.id,
      body: message.body,
      createdAt: message.createdAt,
      isMine: true,
    };
  }

  private async assertAccess(
    conversationId: string,
    userId: string,
    role: UserRole,
  ) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: {
        teacher: true,
        student: { include: { parent: true } },
      },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');

    if (role === UserRole.TEACHER) {
      const teacher = await this.prisma.teacher.findUnique({
        where: { userId },
      });
      if (!teacher || teacher.id !== conversation.teacherId) {
        throw new ForbiddenException('Not your conversation');
      }
      return;
    }

    if (role === UserRole.PARENT) {
      if (conversation.student.parent?.userId !== userId) {
        throw new ForbiddenException('Not your conversation');
      }
      return;
    }

    throw new ForbiddenException('Access denied');
  }

  private async teacherClassIds(teacherId: string) {
    const [asClassTeacher, teaching] = await Promise.all([
      this.prisma.class.findMany({
        where: { classTeacherId: teacherId },
        select: { id: true },
      }),
      this.prisma.teacherTeachingClass.findMany({
        where: { teacherId },
        select: { classId: true },
      }),
    ]);
    return [
      ...new Set([
        ...asClassTeacher.map((c) => c.id),
        ...teaching.map((t) => t.classId),
      ]),
    ];
  }
}
